package com.admin.config;

import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.io.ClassPathResource;
import org.springframework.core.io.Resource;
import org.springframework.jdbc.datasource.init.DataSourceInitializer;
import org.springframework.jdbc.datasource.init.ResourceDatabasePopulator;

import javax.sql.DataSource;
import java.io.File;

/**
 * SQLite 資料庫自動初始化配置
 * 首次啟動時自動執行 gost-sqlite.sql 建立表結構和預設資料
 */
@Slf4j
@Configuration
public class SqliteInitConfig {

    @Value("${spring.datasource.url}")
    private String datasourceUrl;

    @Bean
    public DataSourceInitializer dataSourceInitializer(DataSource dataSource) {
        DataSourceInitializer initializer = new DataSourceInitializer();
        initializer.setDataSource(dataSource);

        // 檢查資料庫文件是否已存在（首次啟動才初始化）
        String dbPath = datasourceUrl.replace("jdbc:sqlite:", "");
        File dbFile = new File(dbPath);

        if (!dbFile.exists() || dbFile.length() == 0) {
            log.info("SQLite 資料庫不存在，執行初始化建表...");
            // 確保資料目錄存在
            File parentDir = dbFile.getParentFile();
            if (parentDir != null && !parentDir.exists()) {
                parentDir.mkdirs();
            }

            Resource initScript = new ClassPathResource("gost-sqlite.sql");
            ResourceDatabasePopulator populator = new ResourceDatabasePopulator();
            populator.addScript(initScript);
            populator.setSeparator(";");
            populator.setContinueOnError(false);
            initializer.setDatabasePopulator(populator);
            log.info("SQLite 資料庫初始化完成");
        } else {
            log.info("SQLite 資料庫已存在，跳過初始化: {}", dbPath);
        }

        return initializer;
    }
}
