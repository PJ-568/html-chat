// 使用 IIFE 包裹以避免全局变量污染
(function () {
    var loadingBar = document.querySelector(".loading-bar");
    var progress = document.querySelector(".loading-bar .progress");
    var timer = null;
    let pjax;

    function initAni() {
        loadingBar = document.querySelector(".loading-bar");
        progress = document.querySelector(".loading-bar .progress");
    }

    // 初始化 PJAX
    function initPjax() {
        try {
            const Pjax = window.Pjax || function () { };
            pjax = new Pjax({
                selectors: [
                    "head meta",
                    "head title",
                    "body container",
                    ".pjax-reload"
                ]
            });
        } catch (e) {
            console.log('PJAX 初始化出错：' + e);
        }
    }

    function endLoad() {
        clearInterval(timer);
        progress.style.width = "100%";
        loadingBar.classList.remove("loading");

        setTimeout(function () {
            progress.style.width = 0;
        }, 400);
    }

    // 初始化
    function initialize() {
        initPjax();
        initAni();
    }


    // 触发器
    // 网页加载完毕后触发
    window.addEventListener('DOMContentLoaded', () => initialize());
    // Pjax 开始时执行的函数
    document.addEventListener("pjax:send", function () {
        var loadingBarWidth = 20;
        var MAX_LOADING_WIDTH = 95;

        loadingBar.classList.add("loading");
        progress.style.width = loadingBarWidth + "%";

        clearInterval(timer);
        timer = setInterval(function () {
            loadingBarWidth += 3;

            if (loadingBarWidth > MAX_LOADING_WIDTH) {
                loadingBarWidth = MAX_LOADING_WIDTH;
            }

            progress.style.width = loadingBarWidth + "%";
        }, 500);
    });
    // 监听 Pjax 完成后，重新加载
    document.addEventListener("pjax:complete", function () {
        endLoad();
    });
})();