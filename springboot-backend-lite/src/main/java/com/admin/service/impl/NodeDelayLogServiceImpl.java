package com.admin.service.impl;

import com.admin.entity.NodeDelayLog;
import com.admin.mapper.NodeDelayLogMapper;
import com.admin.service.INodeDelayLogService;
import com.baomidou.mybatisplus.core.conditions.query.QueryWrapper;
import com.baomidou.mybatisplus.extension.service.impl.ServiceImpl;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Map;

@Slf4j
@Service
public class NodeDelayLogServiceImpl extends ServiceImpl<NodeDelayLogMapper, NodeDelayLog> implements INodeDelayLogService {
    
    @Autowired
    private NodeDelayLogMapper nodeDelayLogMapper;

    @Override
    public void cleanOldLogs(Long timestamp) {
        QueryWrapper<NodeDelayLog> queryWrapper = new QueryWrapper<>();
        queryWrapper.lt("created_time", timestamp);
        long start = System.currentTimeMillis();
        int deleted = nodeDelayLogMapper.delete(queryWrapper);
        log.info("Cleaned up {} old node delay log records in {}ms", deleted, System.currentTimeMillis() - start);
    }

    @Override
    public List<Map<String, Object>> getAggregatedDelay(Long nodeId, Long timeRangeInMillis) {
        Long startTime = System.currentTimeMillis() - timeRangeInMillis;
        return nodeDelayLogMapper.getAggregatedDelayByNodeAndSource(nodeId, startTime);
    }

    /**
     * Scheduled task to clean logs older than 7 days
     * Runs every day at 03:00 AM
     */
    @Scheduled(cron = "0 0 3 * * ?")
    public void scheduledLogCleanup() {
        log.info("Starting scheduled cleanup of old node delay logs");
        // 7 days in milliseconds
        long sevenDaysAgo = System.currentTimeMillis() - (7L * 24 * 60 * 60 * 1000);
        cleanOldLogs(sevenDaysAgo);
    }
}
