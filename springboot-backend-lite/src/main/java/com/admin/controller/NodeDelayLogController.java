package com.admin.controller;

import com.admin.common.annotation.RequireRole;
import com.admin.common.aop.LogAnnotation;
import com.admin.common.lang.R;
import com.admin.entity.NodeDelayLog;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@CrossOrigin
@RequestMapping("/api/v1/node_delay")
public class NodeDelayLogController extends BaseController {


    /**
     * API for frontend panel to query aggregated delay data
     * timeRange: 1 (1H), 4 (4H), 24 (24H), 168 (1W)
     */
    @LogAnnotation
    @RequireRole
    @PostMapping("/stats")
    public R getDelayStats(@RequestBody Map<String, Object> params) {
        if (!params.containsKey("nodeId") || !params.containsKey("timeRangeHours")) {
            return R.err("Missing required parameters");
        }
        Long nodeId = Long.valueOf(params.get("nodeId").toString());
        Integer hours = Integer.valueOf(params.get("timeRangeHours").toString());
        
        // Convert hours to milliseconds
        Long timeRangeInMillis = hours * 60L * 60L * 1000L;
        
        List<Map<String, Object>> stats = nodeDelayLogService.getAggregatedDelay(nodeId, timeRangeInMillis);
        return R.ok(stats);
    }
}
