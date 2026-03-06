package com.admin.controller;

import com.admin.common.annotation.RequireRole;
import com.admin.common.aop.LogAnnotation;
import com.admin.common.lang.R;
import com.admin.entity.DelayTestSource;
import com.admin.entity.Node;
import com.admin.entity.NodeDelayLog;
import com.baomidou.mybatisplus.core.conditions.query.QueryWrapper;
import org.springframework.web.bind.annotation.*;

import java.util.*;
import java.util.stream.Collectors;

/**
 * 節點延遲日誌 Controller
 * 提供延遲統計查詢與節點上報 API
 */
@RestController
@CrossOrigin
@RequestMapping("/api/v1/node_delay")
public class NodeDelayLogController extends BaseController {

    /**
     * 驗證上報請求中的 nodeId 是否存在
     * @return null 表示驗證通過，否則回傳錯誤 R
     */
    private R validateNodeExists(Long nodeId) {
        if (nodeId == null) {
            return R.err("缺少 nodeId");
        }
        Node node = nodeService.getById(nodeId);
        if (node == null) {
            return R.err("無效的 nodeId");
        }
        return null;
    }

    /**
     * 查詢延遲統計數據
     * 前端傳入 nodeId 和 hours，回傳該節點在指定時間範圍內的延遲記錄
     */
    @LogAnnotation
    @RequireRole
    @PostMapping("/stats")
    public R stats(@RequestBody Map<String, Object> params) {
        Long nodeId = params.get("nodeId") != null ? Long.valueOf(params.get("nodeId").toString()) : null;
        Integer hours = params.get("hours") != null ? Integer.valueOf(params.get("hours").toString()) : 1;

        if (nodeId == null) {
            return R.err("缺少 nodeId 參數");
        }

        // 計算時間範圍
        long since = System.currentTimeMillis() - (hours * 3600L * 1000L);

        // 查詢該節點在時間範圍內的所有延遲日誌
        QueryWrapper<NodeDelayLog> wrapper = new QueryWrapper<>();
        wrapper.eq("node_id", nodeId)
               .ge("created_time", since)
               .orderByAsc("created_time");

        List<NodeDelayLog> logs = nodeDelayLogService.list(wrapper);

        if (logs.isEmpty()) {
            return R.ok(new LinkedHashMap<>());
        }

        // 批量載入所有相關測試源（避免 N+1 查詢）
        Set<Long> sourceIds = logs.stream()
                .map(NodeDelayLog::getSourceId)
                .collect(Collectors.toSet());
        List<DelayTestSource> sources = delayTestSourceService.listByIds(sourceIds);
        Map<Long, String> sourceNameMap = sources.stream()
                .collect(Collectors.toMap(DelayTestSource::getId, DelayTestSource::getName, (a, b) -> a));

        // 按 sourceId 分組
        Map<Long, Map<String, Object>> grouped = new LinkedHashMap<>();
        for (NodeDelayLog log : logs) {
            Long sourceId = log.getSourceId();
            if (!grouped.containsKey(sourceId)) {
                Map<String, Object> sourceData = new HashMap<>();
                sourceData.put("sourceName", sourceNameMap.getOrDefault(sourceId, "Source " + sourceId));
                sourceData.put("records", new ArrayList<>());
                grouped.put(sourceId, sourceData);
            }

            Map<String, Object> record = new HashMap<>();
            record.put("time", log.getCreatedTime());
            record.put("latency", log.getLatency());
            record.put("success", log.getSuccess());

            @SuppressWarnings("unchecked")
            List<Map<String, Object>> records = (List<Map<String, Object>>) grouped.get(sourceId).get("records");
            records.add(record);
        }

        return R.ok(grouped);
    }

    /**
     * 節點上報延遲測試結果（單筆）
     */
    @PostMapping("/report")
    public R report(@RequestBody Map<String, Object> params) {
        try {
            Long nodeId = params.get("nodeId") != null ? Long.valueOf(params.get("nodeId").toString()) : null;
            Long sourceId = params.get("sourceId") != null ? Long.valueOf(params.get("sourceId").toString()) : null;

            // 驗證節點存在性
            R validateResult = validateNodeExists(nodeId);
            if (validateResult != null) return validateResult;

            if (sourceId == null) {
                return R.err("缺少 sourceId");
            }

            Double latency = params.get("latency") != null ? Double.valueOf(params.get("latency").toString()) : 0.0;
            Integer success = params.get("success") != null ? Integer.valueOf(params.get("success").toString()) : 0;
            String errorMsg = params.get("errorMsg") != null ? params.get("errorMsg").toString() : null;

            NodeDelayLog log = new NodeDelayLog();
            log.setNodeId(nodeId);
            log.setSourceId(sourceId);
            log.setLatency(latency);
            log.setSuccess(success);
            log.setErrorMsg(errorMsg);
            log.setCreatedTime(System.currentTimeMillis());

            nodeDelayLogService.save(log);

            return R.ok("上報成功");
        } catch (Exception e) {
            return R.err("上報失敗: " + e.getMessage());
        }
    }

    /**
     * 節點批量上報延遲測試結果
     */
    @PostMapping("/report_batch")
    public R reportBatch(@RequestBody Map<String, Object> params) {
        try {
            Long nodeId = params.get("nodeId") != null ? Long.valueOf(params.get("nodeId").toString()) : null;

            // 驗證節點存在性
            R validateResult = validateNodeExists(nodeId);
            if (validateResult != null) return validateResult;

            @SuppressWarnings("unchecked")
            List<Map<String, Object>> results = (List<Map<String, Object>>) params.get("results");
            if (results == null || results.isEmpty()) {
                return R.ok("無數據需上報");
            }

            List<NodeDelayLog> logList = new ArrayList<>();
            long now = System.currentTimeMillis();

            for (Map<String, Object> r : results) {
                NodeDelayLog log = new NodeDelayLog();
                log.setNodeId(nodeId);
                log.setSourceId(r.get("sourceId") != null ? Long.valueOf(r.get("sourceId").toString()) : 0L);
                log.setLatency(r.get("latency") != null ? Double.valueOf(r.get("latency").toString()) : 0.0);
                log.setSuccess(r.get("success") != null ? Integer.valueOf(r.get("success").toString()) : 0);
                log.setErrorMsg(r.get("errorMsg") != null ? r.get("errorMsg").toString() : null);
                log.setCreatedTime(now);
                logList.add(log);
            }

            nodeDelayLogService.saveBatch(logList);
            return R.ok("批量上報成功");
        } catch (Exception e) {
            return R.err("批量上報失敗: " + e.getMessage());
        }
    }

    /**
     * 清理過期延遲日誌（保留最近 7 天數據）
     */
    @LogAnnotation
    @RequireRole
    @PostMapping("/cleanup")
    public R cleanup() {
        long sevenDaysAgo = System.currentTimeMillis() - (7 * 24 * 3600L * 1000L);
        QueryWrapper<NodeDelayLog> wrapper = new QueryWrapper<>();
        wrapper.lt("created_time", sevenDaysAgo);

        int deleted = nodeDelayLogService.count(wrapper);
        nodeDelayLogService.remove(wrapper);

        return R.ok("已清理 " + deleted + " 條過期記錄");
    }
}
