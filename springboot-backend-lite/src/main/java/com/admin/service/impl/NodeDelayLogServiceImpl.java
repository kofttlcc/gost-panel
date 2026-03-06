package com.admin.service.impl;

import com.admin.entity.NodeDelayLog;
import com.admin.mapper.NodeDelayLogMapper;
import com.admin.service.INodeDelayLogService;
import com.baomidou.mybatisplus.extension.service.impl.ServiceImpl;
import org.springframework.stereotype.Service;

/**
 * 節點延遲日誌 Service 實現
 */
@Service
public class NodeDelayLogServiceImpl extends ServiceImpl<NodeDelayLogMapper, NodeDelayLog> implements INodeDelayLogService {
}
