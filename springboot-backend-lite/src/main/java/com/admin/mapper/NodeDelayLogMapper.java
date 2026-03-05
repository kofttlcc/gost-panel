package com.admin.mapper;

import com.admin.entity.NodeDelayLog;
import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;

import java.util.List;
import java.util.Map;

@Mapper
public interface NodeDelayLogMapper extends BaseMapper<NodeDelayLog> {

    @Select("SELECT source_id as sourceId, AVG(delay) as avgDelay " +
            "FROM node_delay_log " +
            "WHERE node_id = #{nodeId} AND created_time >= #{startTime} " +
            "GROUP BY source_id")
    List<Map<String, Object>> getAggregatedDelayByNodeAndSource(@Param("nodeId") Long nodeId, @Param("startTime") Long startTime);
}
