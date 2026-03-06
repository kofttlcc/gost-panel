package com.admin.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

import java.io.Serializable;

/**
 * 延遲測試源實體
 */
@Data
@TableName("delay_test_source")
public class DelayTestSource implements Serializable {

    private static final long serialVersionUID = 1L;

    @TableId(value = "id", type = IdType.AUTO)
    private Long id;

    /**
     * 關聯節點 ID（0 或 null 表示全域）
     */
    private Long nodeId;

    /**
     * 測試源名稱
     */
    private String name;

    /**
     * 測試主機位址
     */
    private String host;

    /**
     * 協議類型：TCPING 或 ICMP
     */
    private String protocol;

    /**
     * TCPING 端口
     */
    private Integer port;

    private Long createdTime;

    private Long updatedTime;
}
