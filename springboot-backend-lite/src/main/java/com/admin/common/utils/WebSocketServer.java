package com.admin.common.utils;

import cn.hutool.core.util.StrUtil;
import com.admin.common.dto.GostDto;
import com.admin.entity.Node;
import com.admin.service.NodeService;
import com.alibaba.fastjson.JSONObject;
import lombok.extern.slf4j.Slf4j;
import org.apache.commons.lang3.StringUtils;
import org.springframework.web.socket.*;
import org.springframework.web.socket.handler.TextWebSocketHandler;

import javax.annotation.Resource;
import java.io.IOException;
import java.util.*;
import java.util.concurrent.*;
import java.util.concurrent.CopyOnWriteArraySet;

@Slf4j
public class WebSocketServer extends TextWebSocketHandler {

    @Resource
    NodeService nodeService;

    @Resource
    com.admin.service.INodeDelayLogService nodeDelayLogService;

    // 存储所有活跃的 WebSocket 连接（
    private static final CopyOnWriteArraySet<WebSocketSession> activeSessions = new CopyOnWriteArraySet<>();
    
    // 存储节点ID和对应的WebSocket session映射
    private static final ConcurrentHashMap<Long, WebSocketSession> nodeSessions = new ConcurrentHashMap<>();
    
    // 为每个session提供锁对象，防止并发发送消息
    private static final ConcurrentHashMap<String, Object> sessionLocks = new ConcurrentHashMap<>();
    
    // 存储等待响应的请求，key为requestId，value为CompletableFuture
    private static final ConcurrentHashMap<String, CompletableFuture<GostDto>> pendingRequests = new ConcurrentHashMap<>();
    
    // 缓存加密器实例，避免重复创建
    private static final ConcurrentHashMap<String, AESCrypto> cryptoCache = new ConcurrentHashMap<>();

    // 專用廣播異步線程池
    private static final ExecutorService broadcastExecutor = Executors.newFixedThreadPool(10);

    static {
        Runtime.getRuntime().addShutdownHook(new Thread(() -> {
            log.info("正在關閉 WebSocket 廣播線程池...");
            broadcastExecutor.shutdown();
            try {
                if (!broadcastExecutor.awaitTermination(5, TimeUnit.SECONDS)) {
                    broadcastExecutor.shutdownNow();
                }
            } catch (InterruptedException e) {
                broadcastExecutor.shutdownNow();
                Thread.currentThread().interrupt();
            }
        }));
    }

    public static class EncryptedMessage {
        private boolean encrypted;
        private String data;
        private Long timestamp;

        public boolean isEncrypted() { return encrypted; }
        public void setEncrypted(boolean encrypted) { this.encrypted = encrypted; }
        public String getData() { return data; }
        public void setData(String data) { this.data = data; }
        public Long getTimestamp() { return timestamp; }
        public void setTimestamp(Long timestamp) { this.timestamp = timestamp; }
    }

    @Override
    public void handleTextMessage(WebSocketSession session, TextMessage message) {
        try {
            if (StringUtils.isNoneBlank(message.getPayload())) {
                
                String id = session.getAttributes().get("id").toString();
                String type = session.getAttributes().get("type").toString();
                String nodeSecret = (String) session.getAttributes().get("nodeSecret");

                String decryptedPayload = decryptMessageIfNeeded(message.getPayload(), nodeSecret);

                if (decryptedPayload.contains("memory_usage")){
                    sendToUser(session, "{\"type\":\"call\"}", nodeSecret);
                } else if (decryptedPayload.contains("DelayTestResults")) {
                    // 處理節點上報的延遲測試結果
                    try {
                        JSONObject delayJson = JSONObject.parseObject(decryptedPayload);
                        com.alibaba.fastjson.JSONArray results = delayJson.getJSONArray("data");
                        if (results != null && !results.isEmpty()) {
                            Long nodeId = Long.valueOf(id);
                            long now = System.currentTimeMillis();
                            java.util.List<com.admin.entity.NodeDelayLog> logList = new java.util.ArrayList<>();
                            for (int i = 0; i < results.size(); i++) {
                                JSONObject r = results.getJSONObject(i);
                                com.admin.entity.NodeDelayLog delayLog = new com.admin.entity.NodeDelayLog();
                                delayLog.setNodeId(nodeId);
                                delayLog.setSourceId(r.getLong("sourceId"));
                                delayLog.setLatency(r.getDouble("latency"));
                                delayLog.setSuccess(r.getInteger("success"));
                                delayLog.setErrorMsg(r.getString("errorMsg"));
                                delayLog.setCreatedTime(now);
                                logList.add(delayLog);
                            }
                            nodeDelayLogService.saveBatch(logList);
                            log.info("節點 {} 上報 {} 筆延遲測試結果", id, logList.size());
                        }
                    } catch (Exception e) {
                        log.info("處理延遲測試結果失敗: {}", e.getMessage());
                    }
                } else if (decryptedPayload.contains("requestId")) {
                    log.info("收到消息: {}", decryptedPayload);
                    try {
                        JSONObject responseJson = JSONObject.parseObject(decryptedPayload);
                        String requestId = responseJson.getString("requestId");
                        String responseMessage = responseJson.getString("message");
                        String responseType = responseJson.getString("type");
                        JSONObject responseData = responseJson.getJSONObject("data");
                        
                        if (requestId != null) {
                            CompletableFuture<GostDto> future = pendingRequests.remove(requestId);
                            if (future != null) {
                                GostDto result = new GostDto();
                                if ("PingResponse".equals(responseType) && responseData != null) {
                                    result.setMsg(responseMessage != null ? responseMessage : "OK");
                                    result.setData(responseData);
                                } else {
                                    result.setMsg(responseMessage != null ? responseMessage : "无响应消息");
                                    if (responseData != null) {
                                        result.setData(responseData);
                                    }
                                }
                                future.complete(result);
                            }
                        }
                    } catch (Exception e) {
                        log.info("处理响应消息失败: {}", e.getMessage(), e);
                    }
                } else {
                    log.info("收到消息: {}", decryptedPayload);
                }

                if (Objects.equals(type, "1")) {
                    JSONObject jsonObject = new JSONObject();
                    jsonObject.put("id", id);
                    jsonObject.put("type", "info");
                    jsonObject.put("data", decryptedPayload);
                    String broadcastMessage = jsonObject.toJSONString();
                    
                    broadcastExecutor.submit(() -> {
                        for (WebSocketSession targetSession : activeSessions) {
                            if (targetSession != null && targetSession.isOpen() && !targetSession.equals(session)) {
                                sendToUser(targetSession, broadcastMessage, null);
                            }
                        }
                    });
                }
            }
        } catch (Exception e) {
            log.info("处理WebSocket消息时发生异常: {}", e.getMessage(), e);
        }
    }
