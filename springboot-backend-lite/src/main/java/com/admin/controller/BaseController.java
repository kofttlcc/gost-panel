package com.admin.controller;

import com.admin.service.*;
import com.admin.service.IDelayTestSourceService;
import com.admin.service.INodeDelayLogService;
import org.springframework.beans.factory.annotation.Autowired;

public class BaseController {

    @Autowired
    UserService userService;

    @Autowired
    NodeService nodeService;

    @Autowired
    UserTunnelService userTunnelService;

    @Autowired
    TunnelService tunnelService;

    @Autowired
    ForwardService forwardService;

    @Autowired
    ViteConfigService viteConfigService;

    @Autowired
    IDelayTestSourceService delayTestSourceService;

    @Autowired
    INodeDelayLogService nodeDelayLogService;

}
