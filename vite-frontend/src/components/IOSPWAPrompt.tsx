import { useState, useEffect } from 'react';


export function IOSPWAPrompt() {
    const [showPrompt, setShowPrompt] = useState(false);

    useEffect(() => {
        // Detect iOS Safari
        const isIos = () => {
            const userAgent = window.navigator.userAgent.toLowerCase();
            return /iphone|ipad|ipod/.test(userAgent);
        };

        const isStandalone = () => {
            // @ts-ignore
            return ('standalone' in window.navigator) && (window.navigator.standalone);
        };

        if (isIos() && !isStandalone()) {
            // Check if we've shown it recently
            const hasShown = localStorage.getItem('pwaPromptShown');
            if (!hasShown) {
                setShowPrompt(true);
            }
        }
    }, []);

    const dismissPrompt = () => {
        setShowPrompt(false);
        localStorage.setItem('pwaPromptShown', 'true');
    };

    if (!showPrompt) return null;

    return (
        <div className="fixed bottom-4 left-4 right-4 z-[9999] flex justify-center pb-safe">
            <div className="max-w-md w-full bg-white dark:bg-zinc-900 rounded-xl shadow-2xl space-y-3 p-4 border border-zinc-200 dark:border-zinc-800 flex flex-row items-center justify-between gap-4">
                <div className="flex-1">
                    <h3 className="text-sm font-semibold mb-1 flex items-center gap-2">
                        <svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><rect x="5" y="2" width="14" height="20" rx="2" ry="2"></rect><line x1="12" y1="18" x2="12.01" y2="18"></line></svg>
                        安裝 Gost-Panel
                    </h3>
                    <p className="text-xs text-zinc-500">
                        點擊 Safari 底部選單的 <strong>分享</strong> 按鈕，然後選擇 <strong>加至主畫面</strong> 以獲得最佳體驗。
                    </p>
                </div>
                <button onClick={dismissPrompt} className="p-2 bg-zinc-100 dark:bg-zinc-800 rounded-full text-red-500 hover:bg-red-50 dark:hover:bg-red-900/30 transition-colors">
                    <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><line x1="18" y1="6" x2="6" y2="18"></line><line x1="6" y1="6" x2="18" y2="18"></line></svg>
                </button>
            </div>
        </div>
    );
}
