-- SQLite DDL for Gost Panel
-- 從 MySQL gost.sql 轉換而來

-- 表結構：forward
CREATE TABLE IF NOT EXISTS "forward" (
  "id" INTEGER PRIMARY KEY AUTOINCREMENT,
  "user_id" INTEGER NOT NULL,
  "user_name" TEXT NOT NULL,
  "name" TEXT NOT NULL,
  "tunnel_id" INTEGER NOT NULL,
  "in_port" INTEGER NOT NULL,
  "out_port" INTEGER DEFAULT NULL,
  "remote_addr" TEXT NOT NULL,
  "strategy" TEXT NOT NULL DEFAULT 'fifo',
  "interface_name" TEXT DEFAULT NULL,
  "in_flow" INTEGER NOT NULL DEFAULT 0,
  "out_flow" INTEGER NOT NULL DEFAULT 0,
  "created_time" INTEGER NOT NULL,
  "updated_time" INTEGER NOT NULL,
  "status" INTEGER NOT NULL,
  "inx" INTEGER NOT NULL DEFAULT 0
);

-- 表結構：node
CREATE TABLE IF NOT EXISTS "node" (
  "id" INTEGER PRIMARY KEY AUTOINCREMENT,
  "name" TEXT NOT NULL,
  "secret" TEXT NOT NULL,
  "ip" TEXT,
  "server_ip" TEXT NOT NULL,
  "port_sta" INTEGER NOT NULL,
  "port_end" INTEGER NOT NULL,
  "version" TEXT DEFAULT NULL,
  "http" INTEGER NOT NULL DEFAULT 0,
  "tls" INTEGER NOT NULL DEFAULT 0,
  "socks" INTEGER NOT NULL DEFAULT 0,
  "created_time" INTEGER NOT NULL,
  "updated_time" INTEGER DEFAULT NULL,
  "status" INTEGER NOT NULL
);

-- 表結構：speed_limit
CREATE TABLE IF NOT EXISTS "speed_limit" (
  "id" INTEGER PRIMARY KEY AUTOINCREMENT,
  "name" TEXT NOT NULL,
  "speed" INTEGER NOT NULL,
  "tunnel_id" INTEGER NOT NULL,
  "tunnel_name" TEXT NOT NULL,
  "created_time" INTEGER NOT NULL,
  "updated_time" INTEGER DEFAULT NULL,
  "status" INTEGER NOT NULL
);

-- 表結構：statistics_flow
CREATE TABLE IF NOT EXISTS "statistics_flow" (
  "id" INTEGER PRIMARY KEY AUTOINCREMENT,
  "user_id" INTEGER NOT NULL,
  "flow" INTEGER NOT NULL,
  "total_flow" INTEGER NOT NULL,
  "time" TEXT NOT NULL,
  "created_time" INTEGER NOT NULL
);

-- 表結構：tunnel
CREATE TABLE IF NOT EXISTS "tunnel" (
  "id" INTEGER PRIMARY KEY AUTOINCREMENT,
  "name" TEXT NOT NULL,
  "traffic_ratio" REAL NOT NULL DEFAULT 1.0,
  "in_node_id" INTEGER NOT NULL,
  "in_ip" TEXT NOT NULL,
  "out_node_id" INTEGER NOT NULL,
  "out_ip" TEXT NOT NULL,
  "type" INTEGER NOT NULL,
  "protocol" TEXT NOT NULL DEFAULT 'tls',
  "flow" INTEGER NOT NULL,
  "tcp_listen_addr" TEXT NOT NULL DEFAULT '[::]',
  "udp_listen_addr" TEXT NOT NULL DEFAULT '[::]',
  "interface_name" TEXT DEFAULT NULL,
  "created_time" INTEGER NOT NULL,
  "updated_time" INTEGER NOT NULL,
  "status" INTEGER NOT NULL
);

-- 表結構：user
CREATE TABLE IF NOT EXISTS "user" (
  "id" INTEGER PRIMARY KEY AUTOINCREMENT,
  "user" TEXT NOT NULL,
  "pwd" TEXT NOT NULL,
  "role_id" INTEGER NOT NULL,
  "exp_time" INTEGER NOT NULL,
  "flow" INTEGER NOT NULL,
  "in_flow" INTEGER NOT NULL DEFAULT 0,
  "out_flow" INTEGER NOT NULL DEFAULT 0,
  "flow_reset_time" INTEGER NOT NULL,
  "num" INTEGER NOT NULL,
  "created_time" INTEGER NOT NULL,
  "updated_time" INTEGER DEFAULT NULL,
  "status" INTEGER NOT NULL
);

-- 預設管理員帳號（密碼: admin123）
INSERT OR IGNORE INTO "user" ("id", "user", "pwd", "role_id", "exp_time", "flow", "in_flow", "out_flow", "flow_reset_time", "num", "created_time", "updated_time", "status")
VALUES (1, 'admin_user', '3c85cdebade1c51cf64ca9f3c09d182d', 0, 2727251700000, 99999, 0, 0, 1, 99999, 1748914865000, 1754011744252, 1);

-- 表結構：user_tunnel
CREATE TABLE IF NOT EXISTS "user_tunnel" (
  "id" INTEGER PRIMARY KEY AUTOINCREMENT,
  "user_id" INTEGER NOT NULL,
  "tunnel_id" INTEGER NOT NULL,
  "speed_id" INTEGER DEFAULT NULL,
  "num" INTEGER NOT NULL,
  "flow" INTEGER NOT NULL,
  "in_flow" INTEGER NOT NULL DEFAULT 0,
  "out_flow" INTEGER NOT NULL DEFAULT 0,
  "flow_reset_time" INTEGER NOT NULL,
  "exp_time" INTEGER NOT NULL,
  "status" INTEGER NOT NULL
);

-- 表結構：vite_config
CREATE TABLE IF NOT EXISTS "vite_config" (
  "id" INTEGER PRIMARY KEY AUTOINCREMENT,
  "name" TEXT NOT NULL UNIQUE,
  "value" TEXT NOT NULL,
  "time" INTEGER NOT NULL
);

-- 預設配置
INSERT OR IGNORE INTO "vite_config" ("id", "name", "value", "time")
VALUES (1, 'app_name', 'flux', 1755147963000);
