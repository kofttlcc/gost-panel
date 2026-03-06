import { useState, useEffect, useCallback } from "react";
import { Card, CardBody, CardHeader } from "@heroui/card";
import { Button } from "@heroui/button";
import { Input } from "@heroui/input";
import { Modal, ModalContent, ModalHeader, ModalBody, ModalFooter } from "@heroui/modal";
import { Chip } from "@heroui/chip";
import { Spinner } from "@heroui/spinner";
import { Select, SelectItem } from "@heroui/select";
import toast from 'react-hot-toast';
import {
    LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer
} from 'recharts';

import {
    createDelaySource,
    getDelaySourceList,
    updateDelaySource,
    deleteDelaySource,
    getDelayStats,
    getNodeList
} from "@/api";

// ===== 類型定義 =====
interface DelayTestSource {
    id: number;
    nodeId?: number | null;
    name: string;
    host: string;
    protocol: string; // TCPING 或 ICMP
    port: number;
    createdAt?: string;
}

interface SourceForm {
    id: number | null;
    nodeId: number | null;
    name: string;
    host: string;
    protocol: string;
    port: number;
}

interface NodeOption {
    id: number;
    name: string;
    connectionStatus?: string;
}

interface DelayDataPoint {
    time: string;
    [sourceName: string]: string | number;
}

// 圖表顏色
const CHART_COLORS = [
    '#3b82f6', '#10b981', '#f59e0b', '#ef4444', '#8b5cf6',
    '#ec4899', '#06b6d4', '#84cc16', '#f97316', '#6366f1'
];

// 時間維度選項
const TIME_RANGES = [
    { label: '1小時', value: 1 },
    { label: '4小時', value: 4 },
    { label: '24小時', value: 24 },
    { label: '1週', value: 168 },
];

export default function DelayPage() {
    // === Tab 狀態 ===
    const [activeTab, setActiveTab] = useState<'sources' | 'stats'>('sources');

    // === 測試源管理 ===
    const [sources, setSources] = useState<DelayTestSource[]>([]);
    const [sourcesLoading, setSourcesLoading] = useState(false);
    const [dialogVisible, setDialogVisible] = useState(false);
    const [dialogTitle, setDialogTitle] = useState('');
    const [isEdit, setIsEdit] = useState(false);
    const [submitLoading, setSubmitLoading] = useState(false);
    const [deleteModalOpen, setDeleteModalOpen] = useState(false);
    const [deleteLoading, setDeleteLoading] = useState(false);
    const [sourceToDelete, setSourceToDelete] = useState<DelayTestSource | null>(null);
    const [form, setForm] = useState<SourceForm>({
        id: null, nodeId: null, name: '', host: '', protocol: 'TCPING', port: 443
    });
    const [errors, setErrors] = useState<Record<string, string>>({});

    // === 延遲統計 ===
    const [nodes, setNodes] = useState<NodeOption[]>([]);
    const [selectedNodeId, setSelectedNodeId] = useState<number | null>(null);
    const [timeRange, setTimeRange] = useState(1);
    const [chartData, setChartData] = useState<DelayDataPoint[]>([]);
    const [chartSourceNames, setChartSourceNames] = useState<string[]>([]);
    const [statsLoading, setStatsLoading] = useState(false);

    // === 初始載入 ===
    useEffect(() => {
        loadSources();
        loadNodes();
    }, []);

    // === 測試源 CRUD ===
    const loadSources = async () => {
        setSourcesLoading(true);
        try {
            const res = await getDelaySourceList();
            if (res.code === 0) {
                setSources(res.data || []);
            } else {
                toast.error(res.msg || '載入測試源失敗');
            }
        } catch {
            toast.error('網路錯誤');
        } finally {
            setSourcesLoading(false);
        }
    };

    const loadNodes = async () => {
        try {
            const res = await getNodeList();
            if (res.code === 0) {
                setNodes((res.data || []).map((n: any) => ({
                    id: n.id,
                    name: n.name,
                    connectionStatus: n.status === 1 ? 'online' : 'offline'
                })));
            }
        } catch { /* 靜默 */ }
    };

    const validateForm = (): boolean => {
        const e: Record<string, string> = {};
        if (!form.name.trim()) e.name = '請輸入名稱';
        if (!form.host.trim()) e.host = '請輸入主機位址';
        if (form.protocol === 'TCPING' && (!form.port || form.port < 1 || form.port > 65535)) {
            e.port = '端口範圍 1-65535';
        }
        setErrors(e);
        return Object.keys(e).length === 0;
    };

    const handleAdd = () => {
        setDialogTitle('新增測試源');
        setIsEdit(false);
        setForm({ id: null, nodeId: null, name: '', host: '', protocol: 'TCPING', port: 443 });
        setErrors({});
        setDialogVisible(true);
    };

    const handleEdit = (s: DelayTestSource) => {
        setDialogTitle('編輯測試源');
        setIsEdit(true);
        setForm({ id: s.id, nodeId: s.nodeId || null, name: s.name, host: s.host, protocol: s.protocol, port: s.port });
        setErrors({});
        setDialogVisible(true);
    };

    const handleDelete = (s: DelayTestSource) => {
        setSourceToDelete(s);
        setDeleteModalOpen(true);
    };

    const confirmDelete = async () => {
        if (!sourceToDelete) return;
        setDeleteLoading(true);
        try {
            const res = await deleteDelaySource(sourceToDelete.id);
            if (res.code === 0) {
                toast.success('刪除成功');
                setSources(prev => prev.filter(s => s.id !== sourceToDelete.id));
                setDeleteModalOpen(false);
                setSourceToDelete(null);
            } else {
                toast.error(res.msg || '刪除失敗');
            }
        } catch {
            toast.error('網路錯誤');
        } finally {
            setDeleteLoading(false);
        }
    };

    const handleSubmit = async () => {
        if (!validateForm()) return;
        setSubmitLoading(true);
        try {
            const data = {
                ...form,
                port: form.protocol === 'ICMP' ? 0 : form.port
            };
            const apiCall = isEdit ? updateDelaySource : createDelaySource;
            const res = await apiCall(data);
            if (res.code === 0) {
                toast.success(isEdit ? '更新成功' : '建立成功');
                setDialogVisible(false);
                loadSources();
            } else {
                toast.error(res.msg || '操作失敗');
            }
        } catch {
            toast.error('網路錯誤');
        } finally {
            setSubmitLoading(false);
        }
    };

    // === 延遲統計 ===
    const loadStats = useCallback(async () => {
        if (!selectedNodeId) return;
        setStatsLoading(true);
        try {
            const res = await getDelayStats({ nodeId: selectedNodeId, hours: timeRange });
            if (res.code === 0 && res.data) {
                // 後端回傳格式: { sourceId: { sourceName, records: [{ time, latency }] } }
                const rawData = res.data;
                const sourceKeys = Object.keys(rawData);
                const names: string[] = [];
                const timeMap: Record<string, Record<string, number>> = {};

                sourceKeys.forEach(key => {
                    const src = rawData[key];
                    const srcName = src.sourceName || `Source ${key}`;
                    names.push(srcName);
                    (src.records || []).forEach((r: any) => {
                        const t = r.time || r.created_at;
                        if (!timeMap[t]) timeMap[t] = {};
                        timeMap[t][srcName] = r.latency ?? r.latency_ms ?? 0;
                    });
                });

                const sorted = Object.keys(timeMap).sort();
                const points: DelayDataPoint[] = sorted.map(t => {
                    const point: DelayDataPoint = { time: formatTime(t) };
                    names.forEach(n => { point[n] = timeMap[t][n] ?? 0; });
                    return point;
                });

                setChartSourceNames(names);
                setChartData(points);
            } else {
                setChartData([]);
                setChartSourceNames([]);
            }
        } catch {
            toast.error('載入統計失敗');
        } finally {
            setStatsLoading(false);
        }
    }, [selectedNodeId, timeRange]);

    useEffect(() => {
        if (activeTab === 'stats' && selectedNodeId) {
            loadStats();
        }
    }, [activeTab, selectedNodeId, timeRange, loadStats]);

    const formatTime = (t: string): string => {
        try {
            const d = new Date(t);
            if (timeRange <= 4) {
                return `${d.getHours().toString().padStart(2, '0')}:${d.getMinutes().toString().padStart(2, '0')}`;
            } else if (timeRange <= 24) {
                return `${d.getHours().toString().padStart(2, '0')}:${d.getMinutes().toString().padStart(2, '0')}`;
            } else {
                return `${(d.getMonth() + 1)}/${d.getDate()} ${d.getHours().toString().padStart(2, '0')}:00`;
            }
        } catch {
            return t;
        }
    };

    // ===== 渲染 =====
    return (
        <div className="px-3 lg:px-6 py-8">
            {/* 頁面頭部 + Tab 切換 */}
            <div className="flex items-center justify-between mb-6">
                <div className="flex gap-2">
                    <Button
                        size="sm"
                        variant={activeTab === 'sources' ? 'solid' : 'flat'}
                        color={activeTab === 'sources' ? 'primary' : 'default'}
                        onPress={() => setActiveTab('sources')}
                    >
                        測試源管理
                    </Button>
                    <Button
                        size="sm"
                        variant={activeTab === 'stats' ? 'solid' : 'flat'}
                        color={activeTab === 'stats' ? 'primary' : 'default'}
                        onPress={() => setActiveTab('stats')}
                    >
                        延遲統計
                    </Button>
                </div>
                {activeTab === 'sources' && (
                    <Button size="sm" variant="flat" color="primary" onPress={handleAdd}>
                        新增
                    </Button>
                )}
            </div>

            {/* Tab 1: 測試源管理 */}
            {activeTab === 'sources' && (
                <>
                    {sourcesLoading ? (
                        <div className="flex items-center justify-center h-64">
                            <div className="flex items-center gap-3">
                                <Spinner size="sm" />
                                <span className="text-default-600">正在載入...</span>
                            </div>
                        </div>
                    ) : sources.length === 0 ? (
                        <Card className="shadow-sm border border-gray-200 dark:border-gray-700">
                            <CardBody className="text-center py-16">
                                <div className="flex flex-col items-center gap-4">
                                    <div className="w-16 h-16 bg-default-100 rounded-full flex items-center justify-center">
                                        <svg className="w-8 h-8 text-default-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M13 10V3L4 14h7v7l9-11h-7z" />
                                        </svg>
                                    </div>
                                    <div>
                                        <h3 className="text-lg font-semibold text-foreground">暫無測試源</h3>
                                        <p className="text-default-500 text-sm mt-1">點擊「新增」按鈕開始配置延遲測試源</p>
                                    </div>
                                </div>
                            </CardBody>
                        </Card>
                    ) : (
                        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
                            {sources.map(s => (
                                <Card key={s.id} className="shadow-sm border border-divider hover:shadow-md transition-shadow duration-200">
                                    <CardHeader className="pb-2">
                                        <div className="flex justify-between items-start w-full">
                                            <h3 className="font-semibold text-foreground text-sm truncate">{s.name}</h3>
                                            <Chip
                                                color={s.protocol === 'TCPING' ? 'primary' : 'secondary'}
                                                variant="flat" size="sm" className="text-xs"
                                            >
                                                {s.protocol}
                                            </Chip>
                                        </div>
                                    </CardHeader>
                                    <CardBody className="pt-0 pb-3">
                                        <div className="space-y-2 mb-4">
                                            <div className="flex justify-between text-sm">
                                                <span className="text-default-600">主機</span>
                                                <span className="font-mono text-xs truncate ml-2">{s.host}</span>
                                            </div>
                                            <div className="flex justify-between text-sm">
                                                <span className="text-default-600">節點限制</span>
                                                <span className="text-xs truncate ml-2">
                                                    {!s.nodeId || s.nodeId === 0 ? "全部節點 (全域)" : nodes.find(n => n.id === s.nodeId)?.name || `節點 ID: ${s.nodeId}`}
                                                </span>
                                            </div>
                                            {s.protocol === 'TCPING' && (
                                                <div className="flex justify-between text-sm">
                                                    <span className="text-default-600">端口</span>
                                                    <span className="text-xs">{s.port}</span>
                                                </div>
                                            )}
                                        </div>
                                        <div className="flex gap-1.5">
                                            <Button size="sm" variant="flat" color="primary" className="flex-1" onPress={() => handleEdit(s)}>
                                                編輯
                                            </Button>
                                            <Button size="sm" variant="flat" color="danger" className="flex-1" onPress={() => handleDelete(s)}>
                                                刪除
                                            </Button>
                                        </div>
                                    </CardBody>
                                </Card>
                            ))}
                        </div>
                    )}
                </>
            )}

            {/* Tab 2: 延遲統計 */}
            {activeTab === 'stats' && (
                <div className="space-y-4">
                    {/* 篩選列 */}
                    <Card className="shadow-sm border border-divider">
                        <CardBody>
                            <div className="flex flex-wrap gap-4 items-end">
                                <div className="w-64">
                                    <Select
                                        label="選擇節點"
                                        placeholder="請選擇節點"
                                        variant="bordered"
                                        size="sm"
                                        selectedKeys={selectedNodeId ? [String(selectedNodeId)] : []}
                                        onSelectionChange={(keys) => {
                                            const val = Array.from(keys)[0];
                                            setSelectedNodeId(val ? Number(val) : null);
                                        }}
                                    >
                                        {nodes.map(n => (
                                            <SelectItem key={String(n.id)}>
                                                {n.name}
                                            </SelectItem>
                                        ))}
                                    </Select>
                                </div>
                                <div className="flex gap-1">
                                    {TIME_RANGES.map(tr => (
                                        <Button
                                            key={tr.value}
                                            size="sm"
                                            variant={timeRange === tr.value ? 'solid' : 'flat'}
                                            color={timeRange === tr.value ? 'primary' : 'default'}
                                            onPress={() => setTimeRange(tr.value)}
                                        >
                                            {tr.label}
                                        </Button>
                                    ))}
                                </div>
                                <Button size="sm" variant="flat" color="success" onPress={loadStats} isDisabled={!selectedNodeId}>
                                    刷新
                                </Button>
                            </div>
                        </CardBody>
                    </Card>

                    {/* 圖表區域 */}
                    <Card className="shadow-sm border border-divider">
                        <CardHeader>
                            <h3 className="font-semibold text-foreground text-sm">延遲趨勢圖 (ms)</h3>
                        </CardHeader>
                        <CardBody>
                            {!selectedNodeId ? (
                                <div className="flex items-center justify-center h-64 text-default-400">
                                    請先選擇一個節點
                                </div>
                            ) : statsLoading ? (
                                <div className="flex items-center justify-center h-64">
                                    <Spinner size="sm" />
                                    <span className="ml-2 text-default-600">載入中...</span>
                                </div>
                            ) : chartData.length === 0 ? (
                                <div className="flex items-center justify-center h-64 text-default-400">
                                    暫無延遲資料
                                </div>
                            ) : (
                                <ResponsiveContainer width="100%" height={360}>
                                    <LineChart data={chartData} margin={{ top: 5, right: 30, left: 0, bottom: 5 }}>
                                        <CartesianGrid strokeDasharray="3 3" stroke="var(--heroui-default-200)" />
                                        <XAxis dataKey="time" tick={{ fontSize: 11 }} stroke="var(--heroui-default-400)" />
                                        <YAxis tick={{ fontSize: 11 }} stroke="var(--heroui-default-400)" unit="ms" />
                                        <Tooltip
                                            contentStyle={{
                                                backgroundColor: 'var(--heroui-content1)',
                                                border: '1px solid var(--heroui-default-200)',
                                                borderRadius: '8px',
                                                fontSize: '12px'
                                            }}
                                        />
                                        <Legend wrapperStyle={{ fontSize: '12px' }} />
                                        {chartSourceNames.map((name, idx) => (
                                            <Line
                                                key={name}
                                                type="monotone"
                                                dataKey={name}
                                                stroke={CHART_COLORS[idx % CHART_COLORS.length]}
                                                strokeWidth={2}
                                                dot={false}
                                                activeDot={{ r: 4 }}
                                            />
                                        ))}
                                    </LineChart>
                                </ResponsiveContainer>
                            )}
                        </CardBody>
                    </Card>
                </div>
            )}

            {/* 新增/編輯 Modal */}
            <Modal
                isOpen={dialogVisible}
                onOpenChange={(open) => { if (!open) setDialogVisible(false); }}
                size="lg"
                backdrop="blur"
                placement="center"
            >
                <ModalContent>
                    {(onClose: () => void) => (
                        <>
                            <ModalHeader>{dialogTitle}</ModalHeader>
                            <ModalBody>
                                <div className="space-y-4">
                                    <Input
                                        label="名稱"
                                        placeholder="例：Google DNS"
                                        value={form.name}
                                        onChange={(e) => setForm(prev => ({ ...prev, name: e.target.value }))}
                                        variant="bordered"
                                        isInvalid={!!errors.name}
                                        errorMessage={errors.name}
                                    />
                                    <Input
                                        label="主機位址"
                                        placeholder="例：8.8.8.8 或 google.com"
                                        value={form.host}
                                        onChange={(e) => setForm(prev => ({ ...prev, host: e.target.value }))}
                                        variant="bordered"
                                        isInvalid={!!errors.host}
                                        errorMessage={errors.host}
                                    />
                                    <Select
                                        label="關聯節點"
                                        placeholder="選擇特定節點 (預設全域)"
                                        variant="bordered"
                                        selectedKeys={form.nodeId ? [String(form.nodeId)] : []}
                                        onSelectionChange={(keys) => {
                                            const val = Array.from(keys)[0];
                                            setForm(prev => ({ ...prev, nodeId: val ? Number(val) : null }));
                                        }}
                                    >
                                        {[
                                            { id: '', name: '全局 (所有節點)' },
                                            ...nodes.map(n => ({ id: String(n.id), name: n.name }))
                                        ].map(n => (
                                            <SelectItem key={n.id}>
                                                {n.name}
                                            </SelectItem>
                                        ))}
                                    </Select>
                                    <Select
                                        label="協議"
                                        variant="bordered"
                                        selectedKeys={[form.protocol]}
                                        onSelectionChange={(keys) => {
                                            const val = Array.from(keys)[0] as string;
                                            setForm(prev => ({ ...prev, protocol: val || 'TCPING' }));
                                        }}
                                    >
                                        <SelectItem key="TCPING">TCPING</SelectItem>
                                        <SelectItem key="ICMP">ICMP</SelectItem>
                                    </Select>
                                    {form.protocol === 'TCPING' && (
                                        <Input
                                            label="端口"
                                            type="number"
                                            placeholder="443"
                                            value={String(form.port)}
                                            onChange={(e) => setForm(prev => ({ ...prev, port: parseInt(e.target.value) || 0 }))}
                                            variant="bordered"
                                            isInvalid={!!errors.port}
                                            errorMessage={errors.port}
                                        />
                                    )}
                                </div>
                            </ModalBody>
                            <ModalFooter>
                                <Button color="default" variant="light" onPress={onClose}>取消</Button>
                                <Button color="primary" onPress={handleSubmit} isLoading={submitLoading}>
                                    {isEdit ? '更新' : '建立'}
                                </Button>
                            </ModalFooter>
                        </>
                    )}
                </ModalContent>
            </Modal>

            {/* 刪除確認 Modal */}
            <Modal
                isOpen={deleteModalOpen}
                onOpenChange={(open) => { if (!open) { setDeleteModalOpen(false); setSourceToDelete(null); } }}
                size="sm"
                backdrop="blur"
                placement="center"
            >
                <ModalContent>
                    {(onClose: () => void) => (
                        <>
                            <ModalHeader>確認刪除</ModalHeader>
                            <ModalBody>
                                <p className="text-sm text-default-600">
                                    確定要刪除測試源 <strong>{sourceToDelete?.name}</strong> 嗎？此操作不可逆，相關的歷史日誌也會一併刪除。
                                </p>
                            </ModalBody>
                            <ModalFooter>
                                <Button color="default" variant="light" onPress={onClose}>取消</Button>
                                <Button color="danger" onPress={confirmDelete} isLoading={deleteLoading}>刪除</Button>
                            </ModalFooter>
                        </>
                    )}
                </ModalContent>
            </Modal>
        </div>
    );
}
