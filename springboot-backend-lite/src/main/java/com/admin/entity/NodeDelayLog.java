package com.admin.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

import java.io.Serializable;

/**
 * 節點延遲測試日誌實體
 */
@Data
@TableName("node_delay_log")
public class NodeDelayLog implements Serializable {

    private static final long serialVersionUID = 1L;

    @TableId(value = "id", type = IdType.AUTO)
    private Long id;

    /**
     * 節點 ID
     */
    private Long nodeId;

    /**
     * 測試源 ID
     */
    private Long sourceId;

    /**
     * 延遲值 (毫秒)
     */
    private Double latency;

    /**
     * 是否成功
     */
    private Integer success;

    /**
     * 錯誤訊息
     */
    private String errorMsg;

    /**
     * 記錄時間（時間戳）
     */
    private Long createdTime;
}
