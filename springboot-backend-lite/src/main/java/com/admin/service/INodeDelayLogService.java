package com.admin.service;

import com.admin.entity.NodeDelayLog;
import com.baomidou.mybatisplus.extension.service.IService;

import java.util.List;
import java.util.Map;

public interface INodeDelayLogService extends IService<NodeDelayLog> {
    
    /**
     * Delete log records older than the specified timestamp
     * @param timestamp timestamp in milliseconds
     */
    void cleanOldLogs(Long timestamp);

    /**
     * Get aggregated delay statistics for a specific node and time range
     * @param nodeId node ID
     * @param timeRangeInMillis time range to look back in milliseconds
     * @return List of aggregated delay data
     */
    List<Map<String, Object>> getAggregatedDelay(Long nodeId, Long timeRangeInMillis);
}
