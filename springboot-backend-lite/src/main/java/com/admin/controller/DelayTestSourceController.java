package com.admin.controller;

import com.admin.common.annotation.RequireRole;
import com.admin.common.aop.LogAnnotation;
import com.admin.common.lang.R;
import com.admin.entity.DelayTestSource;
import com.baomidou.mybatisplus.core.conditions.query.QueryWrapper;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;
import com.admin.common.utils.WebSocketServer;
import com.alibaba.fastjson.JSONObject;

@RestController
@CrossOrigin
@RequestMapping("/api/v1/delay_source")
public class DelayTestSourceController extends BaseController {

    private void syncSourcesToAllOnlineNodes() {
        List<DelayTestSource> allSources = delayTestSourceService.list();
        // Find all online nodes
        List<com.admin.entity.Node> onlineNodes = nodeService.list(
                new QueryWrapper<com.admin.entity.Node>().eq("status", 1)
        );
        for (com.admin.entity.Node node : onlineNodes) {
             JSONObject config = new JSONObject();
             // 過濾此節點專屬測試源或全域測試源
             List<DelayTestSource> nodeSources = new java.util.ArrayList<>();
             for (DelayTestSource source : allSources) {
                 if (source.getNodeId() == null || source.getNodeId() == 0L || source.getNodeId().equals(node.getId())) {
                     nodeSources.add(source);
                 }
             }
             config.put("sources", nodeSources);
             WebSocketServer.send_msg(node.getId(), config, "SetDelayTestSources");
        }
    }

    @LogAnnotation
    @RequireRole
    @PostMapping("/create")
    public R create(@Validated @RequestBody DelayTestSource source) {
        long now = System.currentTimeMillis();
        source.setCreatedTime(now);
        source.setUpdatedTime(now);
        delayTestSourceService.save(source);
        syncSourcesToAllOnlineNodes();
        return R.ok("Create source success");
    }

    @LogAnnotation
    @RequireRole
    @PostMapping("/list")
    public R list() {
        return R.ok(delayTestSourceService.list());
    }

    @LogAnnotation
    @RequireRole
    @PostMapping("/update")
    public R update(@Validated @RequestBody DelayTestSource source) {
        source.setUpdatedTime(System.currentTimeMillis());
        boolean success = delayTestSourceService.updateById(source);
        if (success) {
            syncSourcesToAllOnlineNodes();
        }
        return success ? R.ok("Update success") : R.err("Update failed");
    }

    @LogAnnotation
    @RequireRole
    @PostMapping("/delete")
    public R delete(@RequestBody Map<String, Object> params) {
        if (!params.containsKey("id") || params.get("id") == null) {
            return R.err("Missing id parameter");
        }
        Long id = Long.valueOf(params.get("id").toString());
        boolean success = delayTestSourceService.removeById(id);
        
        if (success) {
            syncSourcesToAllOnlineNodes();
            // Also clean up related logs
            QueryWrapper<com.admin.entity.NodeDelayLog> wrapper = new QueryWrapper<>();
            wrapper.eq("source_id", id);
            nodeDelayLogService.remove(wrapper);
            return R.ok("Delete success");
        }
        
        return R.err("Delete failed");
    }
}
