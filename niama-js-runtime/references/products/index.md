# 安全产品强制命中索引

产品参考文档只用于识别常见安全产品、优先观察点和常见坑，不替代当前目标实测。补入 `code.js` 的任何环境值、API 行为、事件顺序、异常栈、descriptor、prototype、`toString` 外观，都必须来自当前目标的 `jscall` 定位证据和匹配当前目标的 `ruyitrace/` 真实值。

使用规则：
- 目标名称、参数名、脚本名、Cookie、Header、URL、响应体或日志出现同类安全产品特征时，必须命中本索引中的产品
- 先读本索引判断命中特征，再只读命中的产品文档
- 一个任务可以同时命中验证码产品和签名产品；例如京东登录可同时读取 `jd_jcap.md` 与 `jd.md`
- 阶段 0-3 判定为 `captcha`、`hybrid`，或 `full_flow` 明确包含验证码 / challenge 子链时，先命中验证码 / challenge 文档，再按后续业务请求命中签名 / 加密文档；登录态状态型业务动作按具体产品特征命中对应文档
- 命中后必须在阶段输出或进展清单中写明：安全产品同类特征、命中的产品、读取的产品文档
- 如果出现同类安全产品特征但无法映射到现有文档，必须记录为“未知安全产品特征”，并按当前目标实测继续定位；不得假装没有产品特征
- 产品文档提供观察顺序和常见坑，不允许直接套旧值、旧环境或旧请求链
- 产品文档中出现的 `rtproxy` / `rtwatch` / `rt_log` 观察建议按本 skill 的 Node 补环境路线执行，不得扩展为其它执行层流程
- 安全产品、验证码产品、动态签名 SDK、Worker/WASM/VM-like runtime 都可能存在动态执行载荷或不透明 payload；一份 trace 通过只代表当前版本可用，不代表跨版本稳定
- 产品文档中提到的动态 JS、challenge payload、二进制 body、Worker 脚本、WASM、eval/new Function、server 下发 blob 或 opcode-like 数据，都应按版本材料记录 hash 和适用目标集合；无法确认是否为 VMP 字节流时，按多版本风险候选处理

## datadome

命中特征：
- Cookie 中出现 `datadome`
- 响应头出现 `x-datadome`、`x-datadome-cid`、`x-dd-b`
- 页面 HTML 出现 `var dd={...}` 或 `var ddm={...}`
- 响应体出现 `You have been blocked`、`Please enable JS`
- 请求链出现 `ct.captcha-delivery.com/c.js`、`ct.captcha-delivery.com/i.js`
- 请求链出现 `geo.captcha-delivery.com/interstitial/`
- 请求链出现 `geo.captcha-delivery.com/captcha/`、`geo.captcha-delivery.com/captcha/check`
- 请求链出现 `dd.prod.captcha-delivery.com/image/`、`dd.prod.captcha-delivery.com/audio/`
- 页面通过后加载 `js.datadome.co/tags.js`
- interstitial 请求或响应出现 `payload`、`plv3`、`ps`、`view:"redirect"`、`view:"captcha"`、`ir`
- captcha 校验请求出现 `ddCaptchaChallenge`、`ddCaptchaEncodedPayload`、`ddCaptchaResponse`、`ddCaptchaEnv`、`ddCaptchaAudioChallenge`

读取：
- `references/products/datadome.md`

## dy_abgous

命中特征：
- 目标参数为 `a_bogus`
- 目标接口路径常见于 `/aweme/v1/`、`/aweme/v2/`、`/webcast/`
- 页面或运行链中出现 `webmssdk`、`sdk-glue`、`bdms`、`SecureSDK`、`web_protect`
- 目标请求最终被追加 `a_bogus`、`msToken`、`verifyFp`、`fp`
- `URLSearchParams.has/append/set` 能观察到 `a_bogus`

读取：
- `references/products/dy_abgous.md`

## dy_creator_im

命中特征：
- 目标接口或日志中出现 `imapi.douyin.com/v1/message/send`
- 目标接口或日志中出现 `imapi.douyin.com/v2/message/get_by_user_init`
- 目标接口或日志中出现 `imapi.douyin.com/v2/conversation/create`
- 目标接口或日志中出现 `imapi.douyin.com/v3/conversation/mark_read`
- 目标链路中出现 `frontier-im.douyin.com/ws/v2`
- 目标接口或日志中出现 `creator.douyin.com/passport/safe/get_identity_security_token/`
- 目标接口或日志中出现 `creator.douyin.com/aweme/v1/im/consistency/action/report`
- Header、Cookie 或日志中出现 `bd-ticket-guard-client-data`、`bd-ticket-guard-ree-public-key`、`bd_ticket_guard_client_data`
- 业务字段或日志中出现 `identity_security_token`、`identity_security_device_id`
- JS 模块、调用栈或日志中出现 `ActionConsistencyManager`、`ActionType`、`getUidFromSecUid`
- 业务字段中出现 `conversation_id`、`conversation_short_id`、`ticket`

读取：
- `references/products/dy_creator_im.md`
- 如果同链路出现 `a_bogus`、`msToken`、`webmssdk`、`sdk-glue`、`bdms`、`SecureSDK`、`web_protect`，同时读取 `references/products/dy_abgous.md`

## jd_daojia_ws

命中特征：
- 目标链路中出现 `wss://ws1-dd.jd.com/`
- 目标站点或接口出现 `store.jddj.com`、`sff.jddj.com/api`
- 接口名出现 `dsm.o2o.order.dongdong.token.query`
- 接口名出现 `dsm.o2o.order.dongdong.update.connect`
- 业务接口出现 `dsm.o2o.order.cater.pcAllOrderListQuery`、`dsm.o2o.order.cater.pickOrder`
- WebSocket 消息出现 `auth`、`auth_result`、`client_heartbeat`、`chat_message`、`ack`、`failure`
- 字段中出现 `waiterPin`、`eIdMd5`、`nonce`、`stationId`、`stationNo`
- 同链路出现京东 `h5st`、`x-rp-client`、`dsm-eid`

读取：
- `references/products/jd_daojia_ws.md`
- 如果同链路出现京东 `h5st/_stk/request_algo/tk03`，同时读取 `references/products/jd.md`

## ele_accs_lwp

命中特征：
- 目标链路中出现 `ws-msgacs.m.taobao.com/accs/auth`
- 目标链路中出现 `wss-cntaobao.dingtalk.com`
- 目标链路中出现 `ACCS_H5`、`LWP`
- 接口或日志中出现 `getAccsToken`、`AuthCenterService.getToken`
- 接口或日志中出现 `alsc-im-paas.AlscImPaasService.getLoginToken`
- 字段中出现 `imPaaS2LoginToken`
- LWP 包中出现 `/reg`、`/s/sync`、`/r/MessageSend/sendByReceiverScope`
- Header 或 body 中出现 `app-key`、`did`、`wv=im:3,au:3,sy:6`、`mid`、`cid`、`conversationType`

读取：
- `references/products/ele_accs_lwp.md`

## mt_waimai_ws

命中特征：
- 目标链路中出现 `wss://wmdxlwss.meituan.com`
- Cookie 或日志中出现 `wpush_server_url`
- 字段中出现 `wmPoiId`、`acctId`、`device_uuid`、`pushToken`
- JS 或 Python 中出现 `ByteBuffer`、`MTDXPacket`
- JS 入口出现 `get_ws_data`、`get_ws_base64`、`get_message_base64`
- 业务逻辑出现 `send_init_packet`、`send_auto_reply`
- 二进制包或日志中出现 `uri=196619`、`uri=196620`、`uri=196611`
- 消息结构中出现 `TGData.summary`

读取：
- `references/products/mt_waimai_ws.md`

## reese84

命中特征：
- Cookie、响应体、脚本或日志中出现 `reese84`、`84`、`visid_incap_*`、`incap_ses_*`、`nlbi_*`
- 页面返回 iframe block、`_Incapsula_Resource`、短 HTML、`403` 或过渡页
- 页面里动态写入 challenge script `src`，且 `src` 每轮可能变化
- challenge POST body 中出现 `solution.interrogation.p`、`st`、`sr`、`cr`、`og`、`performance`、`version`
- challenge POST 返回 token 后，仍需要验证业务页或业务接口是否真正放行

读取：
- `references/products/reese84.md`

## rs6

命中特征：
- 页面首屏或业务页返回 challenge HTML，包含动态 `meta content`、内联 `script` 和外链自动化 JS
- 页面、脚本或日志中出现 `$_ts`、`$_ts.nsd`、`$_ts.cd`、`$_ts.lcd`
- JS 通过 `document.cookie` 写入长 cookie，cookie 名和值可能随站点或轮次变化
- 业务接口需要额外动态 query 参数，例如当前样本中的 `fr8o9lcS`
- 运行链触达 `XMLHttpRequest.open`、fetch 包装或等价请求边界，用来生成动态请求后缀
- 脚本采集或模拟 `mousemove`、`scroll`、`mousedown`、`mouseup`、`click` 等行为事件
- 同一流程出现入口页 challenge、业务页 challenge、API 前刷新 cookie 等两阶段或多阶段链路

读取：
- `references/products/rs6.md`

## akamai

命中特征：
- Cookie 中出现 `_abck`、`bm_sz`、`ak_bmsc`、`bm_sv`、`bm_mi`
- 运行链中出现 `bmak`、`get_telemetry`、`sensor_data`
- 页面加载无扩展名的随机路径 Akamai 脚本，并向同路径或相邻路径提交 `sensor_data`
- 页面返回 `sec-if-cpt-container`、Akamai challenge 容器、短 HTML、`403` 或保护页
- Python 标准客户端出现 HTTP/2 stream reset、timeout 或 TLS 指纹不匹配，但浏览器正常

读取：
- `references/products/akamai.md`

## tongdun

命中特征：
- 页面加载 `static.trustdecision.com/tdfp/.../fm.js`
- 页面加载 `static.tongdun.net/v3/fm.js`
- 页面、脚本或日志中出现 `TrustDecision`、`TrustDeviceJs`、`Tongdun`、`tdfp`
- 请求链中出现 `cn-fp.apitd.net/web/v2`、`apitd.net`
- 目标字段或业务请求中出现 `black_box`、`blackBox`、`BlackBox`、`blackbox`、`currentBlackBox`、`tddf`
- 业务 Header、Body 或 axios 配置中出现 `Anti-Headers.black_box`、`BlackBox`、`blackbox`、`blackBox`
- 同盾 SDK 触达 `Blob`、`URL.createObjectURL`、`URL.revokeObjectURL`、`Worker`
- TD POST body 常见 `data=<payload>`，业务请求再注入 `black_box`

读取：
- `references/products/tongdun.md`

## aliyun_captcha

命中特征：
- 请求链出现 `captcha-pro-open.aliyuncs.com`、`device.captcha-open.aliyuncs.com`
- 页面或接口响应出现 `requestInfo`、`StaticPath`、`Result`，并按 `StaticPath` 加载 `g.alicdn.com/captcha-frontend/dynamicJS/sg...js`
- 页面动态加载 `g.alicdn.com/captcha-frontend/FeiLin/.../feilin...js`
- 页面、脚本或日志出现 `AWSC`、`AWSCInner`、`AWSCFY`、`__awsc_et__`、`__awscnc_wrapper_id__`、`nocaptcha`、`nc.js`、`fireyejs.js`、`et_f.js`
- WAF/处罚页出现 `aliyun_waf_aa`、`aliyun_waf_oo`、`aliyun_waf_00`、`_waf_bd8ce2ce37`、`sufei-punish`
- 阿里系业务链出现 `refer__1036`、`ssxmod_itna`、`ssxmod_itna2`、`acw_tc`、`x5secdata`、`_____tmd_____/punishTextFetch`、`__bx__`
- 请求链出现 `cf.aliyun.com/nocaptcha/initialize.jsonp`、`fourier.taobao.com/ts`、`tdum.alibaba.com/dss.js`

读取：
- `references/products/aliyun_captcha.md`

## ali_bxua

命中特征：
- 业务请求 Header 中出现 `bx-ua`，值通常以 `231!` 或 `234!` 开头
- 业务请求 Header 中出现 `bx-umidtoken`
- 业务请求 body/metas 中出现 `AsuraId`、`fire_ua`、`fire_umid`
- `AsuraId` 或 `fire_ua` 值通常以 `140#` 开头
- 页面、脚本或日志出现 `securityHeader.min.js`、`securityHeader.initSecurity`、`securityHeader.getSecurityHeaders`
- 初始化参数或日志出现 `dependHeaders`、`bx-umidtoken`、`bx-ua`
- 页面加载 `g.alicdn.com/sd/baxia`、`baxiaCommon.js`、`sd/baxia-entry`
- 页面加载 `g.alicdn.com/AWSC/fireyejs/1.231`、`g.alicdn.com/AWSC/fireyejs/1.234`、`AWSC/WebUMID`、`AWSC/uab/1.140`、`collina.js`
- 页面或脚本出现 `AWSC.configFY`、`fyOBJ.getUA`、`fyOBJ.umidToken`
- 页面或脚本出现 `__napos_awsc_uab__`、`getUabModule`
- storage、Cookie 或日志中出现 `lswucn`、`_um_cn_umsvtn`、`_um_cn__umdata`、`_uab_collina`、`_umcost`、`tfstk__`
- 请求链出现 `ynuf.aliapp.org/service/um.json`、`nt2.ele.me/c/j`、`fourier.alibaba.com/ts`、`fourier.taobao.com/rp`
- 请求链出现 `gm.mmstat.com/a2f1q.bx`
- 最终业务接口返回 `FAIL_SYS_USER_VALIDATE`、`x5 captcha`、`showCaptcha` 或同类用户验证拦截

读取：
- `references/products/ali_bxua.md`
- 如果同链路出现 `captcha-pro-open.aliyuncs.com`、`device.captcha-open.aliyuncs.com`、`x5secdata`、`_____tmd_____/punishTextFetch`、`__bx__`、`sufei-punish`，同时读取 `references/products/aliyun_captcha.md`

## tx_captcha

命中特征：
- 页面或请求链出现 `https://t.captcha.qq.com/TCaptcha.js`
- 页面脚本出现 `new TencentCaptcha`、`TencentCaptcha`、`captcha.show()`
- 请求链出现 `https://t.captcha.qq.com/cap_union_prehandle`
- 请求链出现 `https://t.captcha.qq.com/cap_union_new_verify`
- 请求链出现当前轮 `tdc.js`、`tdc_path`，或脚本中出现 `window.TDC`、`TDC.setData`、`TDC.getData`、`TDC.getInfo`
- 验证码 iframe、模板或资源来自 `captcha.gtimg.com/static/template/drag_ele`
- Cookie、storage 或日志中出现 `TDC_itoken`、`__tdc_st_`
- 题型或脚本中出现 `move_slide`、`watermarkMoveSlide`、`DynAnswerType_POS`
- 初始化响应出现 `comm_captcha_cfg`、`dyn_show_info`、`bg_elem_cfg`、`sprite_url`、`fg_elem_list`、`pow_cfg`、`sess`
- 校验请求体出现 `collect`、`tlg`、`eks`、`sess`、`ans`、`pow_answer`、`pow_calc_time`
- 校验成功响应或页面回调出现 `ticket`、`randstr`

读取：
- `references/products/tx_captcha.md`

## jd_jcap

命中特征：
- 请求链出现 `jcap.m.jd.com/cgi-bin/api/fp`、`/cgi-bin/api/refresh`、`/cgi-bin/api/check`
- 页面或脚本出现 `requireCaptchaPc.js`、`jcap_*.js`、`window.jdCAP`、`jdCAP.captcha`
- 脚本来自 `storage.360buyimg.com/jsresource/jcap/version/.../jcap_*.js`
- 登录链出现 `passport.jd.com/uc/graphic/sessionId/refresh`
- 请求体或响应出现 `graphicCaptchaSessionId`、`graphicCaptchaJwtToken`、`graphicCaptchaVerifyToken`、`ct`、`tk`、`cs`、`se`、`si`、`st`、`vt`
- 响应出现 `tp=30`、`img`、滑块背景/小图字段，例如 `b1`、`b2`
- 最终校验出现 `code=16807`、`s_code=16130`、`code=16808`、`验证失败`、`验证未通过`
- 登录提交联动出现 `h5st`、`_stk`、`aksParamsU`、`aksParamsB`、`/uc/loginService`

读取：
- `references/products/jd_jcap.md`
- 如果同链路还出现京东 `h5st/_stk/request_algo/tk03`，同时读取 `references/products/jd.md`

## kasada

命中特征：
- Header 中出现 `x-kpsdk-ct`、`x-kpsdk-v`、`x-kpsdk-h`、`x-kpsdk-im`、`x-kpsdk-dt`、`x-kpsdk-cr`
- Cookie 中出现 `KP_UIDz` 或其它 `KP_` 前缀状态
- 页面、脚本或请求路径中出现 `KPSDK`、`p.js`、`ips.js`、`/fp`、`/tl`、`/mfc`
- `/fp` 返回 KPSDK 初始化 HTML，`ips.js` 执行后发起 `POST /tl`
- `/tl` body 是二进制指纹 payload，成功后返回新的 `x-kpsdk-ct`

读取：
- `references/products/kasada.md`

## jd

命中特征：
- 目标站点或接口为京东 Web / PC 链路，例如 `item.jd.com`、`search.jd.com`、`api.m.jd.com`
- 京东登录链若出现 `jcap.m.jd.com`、`requireCaptchaPc.js`、`graphicCaptchaVerifyToken` 或 `vt`，优先命中 `jd_jcap`，再按需命中本 `jd` 文档处理 `h5st/_stk`
- 目标参数或请求中出现 `h5st`、`stk`、`request_algo`、`tk03`、`tk06`、`x-api-eid-token`
- 接口中出现 `functionId=pc_detailpage_wareBusiness`、`functionId=pc_search_searchWare`
- Header 中出现 `x-skuid-param`、`x-referer-page`、`x-rp-client`
- Cookie 中出现 `3AB9D23F7A4B3CSS`、`3AB9D23F7A4B3C9B`、`sdtoken`、`thor`、`flash`、`TrackID`
- 响应出现 HTTP `403` 空 body、下发 `X-Rp-Sdtoken`，或业务响应出现签名/风控类错误码

读取：
- `references/products/jd.md`

## alibaba_h5sec_awsc_fireye

命中特征：
- 页面加载 `@alife/alsc-h5-sec/.../securityHeader.min.js`
- 页面加载 `g.alicdn.com/AWSC/AWSC/awsc.js`、`AWSC/fireyejs/.../fireyejs.js`、`AWSC/uab/.../collina.js`、`AWSC/et/.../et_f.js`、`AWSC/WebUMID/.../um.js`
- 页面加载 `g.alicdn.com/sd/baxia/.../baxiaCommon.js`
- JS 调用或 trace 中出现 `securityHeader.getSecurityHeaders`、`AWSC.configFYEx`、`AWSC.configFY`、`AWSCInner.register`
- 请求头出现 `bx-ua`，值以 `231!` 或 `234!` 开头
- 页面加载 `AWSC/fireyejs/1.231.x` 或 `AWSC/fireyejs/1.234.x`，或同一动作窗口出现两次 `securityHeader.getSecurityHeaders`
- 请求头出现 `bx-umidtoken`，常见长度约 68，值以 `T2gA` 开头
- 请求体或业务 metas 中出现 `AsuraId`、`fire_ua`，值以 `140#` 开头
- 请求体或业务 metas 中出现 `fire_umid`
- Cookie / storage 出现 `tfstk`、`cna`、`tfstk__`
- 响应头或响应体出现 `bxpunish`、`x5secdata`、`_____tmd_____/punish`、`__bx__`、`FAIL_SYS_USER_VALIDATE`
- 没有 `captcha-pro-open.aliyuncs.com` / `device.captcha-open.aliyuncs.com` / `StaticPath` / `Result` 题面链路，但业务请求仍因 140/231/cookie/传输层不一致进入 punish

读取：
- `references/products/alibaba_h5sec_awsc_fireye.md`
- 如果同链路还出现阿里云 v2 验证码题面、`requestInfo`、`StaticPath`、`FeiLin`、`Result`，同时读取 `references/products/aliyun_captcha.md`

## aliyun_captcha_v2

命中特征：
- 页面加载 `https://o.alicdn.com/captcha-frontend/aliyunCaptcha/AliyunCaptcha.js`，并调用 `window.initAliyunCaptcha({...})`
- 初始化配置出现 `SceneId`、`prefix`、`mode`、`element`、`button`、`captchaVerifyCallback`、`getInstance`、`slideStyle`
- 请求发往 `https://<prefix>.captcha-open.aliyuncs.com/`，表单含 `Version=2023-03-05`、`Action=InitCaptcha`、`SceneId`、`Mode`、`DeviceData`
- InitCaptcha 响应同时出现 `Success`、`CaptchaType`、`StaticPath`、`CertifyId`、`DeviceConfig`
- 当轮加载 `g.alicdn.com/captcha-frontend/dynamicJS/<version>/sg.<3digits>.<16hex>.js` 与 `captcha-frontend/FeiLin/<version>/feilin...js`
- runtime/DOM 出现 `TRACELESS`、`SLIDING`、`startTracelessVerification`、`aliyunCaptcha-sliding-slider`
- 设备链出现 `cloudauth-device-dualstack.<region>.aliyuncs.com`、`Action=Log2/Log3`，或诊断链出现 `upload.captcha-open.aliyuncs.com`、`Action=UploadLog`
- SDK callback proof 为 `sceneId/certifyId/deviceToken/data`，常被站点业务接口包装为 `captchaRequestParam`；callback 返回值出现 `captchaResult`
- 用户目标描述为阿里云 v2、AliyunCaptcha 2.0、无感/滑块，或强调服务端每轮动态下发 sg
- `StaticPath` 与 `sg.NNN` 是每次成功 InitCaptcha 对当前轮的选择，不是升级序列；必须重新读取精确 URL，禁止按编号或 latest 选择

强命中至少满足一个组合：`AliyunCaptcha.js + initAliyunCaptcha`、`Action=InitCaptcha + CaptchaType/StaticPath/CertifyId/DeviceConfig`、或 `dynamicJS/sg + FeiLin + 四字段 callback proof`。单独出现 `AWSC`、`StaticPath`、`acw_tc` 或 `Log3` 只算弱线索。

读取：
- `references/products/aliyun_captcha_v2.md`
- 同时读取 `references/products/aliyun_captcha.md` 作为阿里产品总入口；如果链路是 `requestInfo + captcha-pro-open/device.captcha-open + Result/direct verify`，按总入口中的旧式分支处理
- 如果主要出现 `securityHeader/AWSC.configFYEx/bx-ua/fire_ua/tfstk/x5secdata/punish`，同时读取 `references/products/alibaba_h5sec_awsc_fireye.md`

## aliyun_captcha_v3

命中特征：
- 页面加载 `o.alicdn.com/captcha-frontend/aliyunCaptcha/AliyunCaptcha.js` 并调用 `initAliyunCaptcha`
- 设备链出现 `Action=Log1`，成功响应包含 `ResultObject.DeviceConfig`
- 本轮从 DeviceConfig 派生并加载 `captcha-frontend/FeiLin/.../feilin...js`，随后出现 `Action=Log2`
- 初始化请求出现 `Action=InitCaptchaV3`，响应出现 `CaptchaType=CHECK_BOX`、`StaticPath`、`CertifyId`
- 本轮按 StaticPath 加载 `captcha-frontend/dynamicJS/<version>/cx.<digits>.<hash>.js`
- 验证阶段出现 `Action=UploadLog`、`Action=Log3`、`Action=VerifyCaptchaV3`
- 校验响应出现 `Success/VerifyResult/VerifyCode`，SDK 生成非空 `captchaVerifyParam` 或同义业务凭证
- 用户强调 FeiLin 与 cx 是每请求动态发放、同轮同会话执行，或要求 CHECK_BOX 行为轨迹和连续 N/N live 验证

强匹配建议：`Log1 + DeviceConfig + InitCaptchaV3 + dynamicJS/cx + VerifyCaptchaV3`。`AliyunCaptcha.js + DeviceConfig` 本身不足以区分 v2/v3，必须继续看 Action、dynamicJS 文件族和最终校验形态。

读取：
- `references/products/aliyun_captcha_v3.md`
- 同时读取 `references/products/aliyun_captcha.md` 作为阿里产品总入口
- 如果链路是 `Action=InitCaptcha + dynamicJS/sg + captchaVerifyCallback`，改读 `references/products/aliyun_captcha_v2.md`

## cloudflare_5s

命中特征：
- 初始业务页出现 Cloudflare Challenge / 5s 页面，例如 `Just a moment...`、`Checking if the site connection is secure`、`Verifying you are human`
- HTML 内联 `_cf_chl_opt`，字段包含 `cvId`、`cZone`、`cType`、`cRay`、`cH`、`cUPMDTk`、`cFPWv`、`cITimeS`、`md`、`mdrd`
- 请求链出现 `/cdn-cgi/challenge-platform/h/.../orchestrate/chl_page/v1?ray=...` 或 `/cdn-cgi/challenge-platform/h/.../flow/ov1...`
- POST header 出现 `cf-chl` / `cf-chl-ra`，URL 或 payload 出现 `__cf_chl_tk`
- 响应或 Cookie 出现 `cf_clearance`，最终仍需要回打原业务 URL 验证放行

读取：
- `references/products/cloudflare_5s.md`

## dy_ticket_guard

命中特征：
- Header 出现 `bd-ticket-guard-client-data`、`bd-ticket-guard-ree-public-key`、`bd-ticket-guard-web-version`、`bd-ticket-guard-web-sign-type` 或 `bd-ticket-guard-version`
- Cookie 出现 `bd_ticket_guard_client_data`、`bd_ticket_guard_client_data_v2`、`_bd_ticket_crypt_cookie` 或 `__security_mc_*`
- localStorage 出现 `security-sdk/s_sdk_crypt_sdk`、`security-sdk/s_sdk_cert_key`、`security-sdk/s_sdk_server_cert_key`、`security-sdk/s_sdk_sign_data_key/web_protect`、`web_secsdk_runtime_cache` 或 `web_runtime_security_uid`
- 链路出现 `SecureSDK`、`web_protect`、`ticket_guard`、`get_client_cert`、`get_sec_ts`、`token/beat`、QR 登录确认或 MFA 验证完成
- 同一会话中 Cookie、security storage、`x-tt-session-dtrait`、`msToken`、`webid`、`verifyFp/fp` 或浏览器 profile 可能来自不同代次，需要判断是否混用

读取：
- `references/products/dy_ticket_guard.md`
- 同链出现 `a_bogus`、`msToken`、`webmssdk`、`sdk-glue` 或 `bdms` 时，同时读取 `references/products/dy_abgous.md`

## dy_verifycenter_slide

命中特征：
- 请求链出现 `rmc.bytedance.com/verifycenter/captcha/v2`、`verify.zijieapi.com/captcha/get` 或 `verify.zijieapi.com/captcha/verify`
- 初始化参数出现 `aid`、`repoId`、`subtype=slide`、`fp=verify_*`、`h5_check_version`、`vc_version`
- 页面或资源链出现 `rmc-captcha`、`captcha.js`、`index.wasm`、`bdms.js`、`verifycenter-collect`
- 日志出现 `turing_verify_sdk`、`h5_init`、`h5_aquire_data`、`h5_action`、`h5_wasm_call`、`h5_jm`、`h5_result`
- 最终提交字段为 `captchaBody`，且链路出现 `captcha.wasm.encrypt`、`TextDecoder.decode(Uint8Array ...)`、`encrypt_version=7`
- 登录触发响应出现 `error_code=1105` 或 “Drag slider to verify”，验证码通过后再次登录进入业务层

读取：
- `references/products/dy_verifycenter_slide.md`
- 如果同链路还出现 `a_bogus`、`msToken`、`verifyFp`、`fp`、`webmssdk`、`SecureSDK`，同时读取 `references/products/dy_abgous.md`

## f5_shape

命中特征：
- Header 中出现一组六个同前缀字段，后缀常见为 `-a`、`-b`、`-c`、`-d`、`-f`、`-z`，例如 `EE30zvQLWf-a/b/c/d/f/z`、`x-jFuguZWB-a/b/c/d/f/z`
- Cookie、脚本、响应头或日志中出现站点随机命名的 Shape 状态，例如 `sRpK8nqm_sc`、`o59a9A4Gx`
- 页面或请求链出现 `F5 Shape`、`Shape Defense`、`bm-verify`、`/_sec/cp_challenge/verify`
- 页面加载伪装第一方的大体积混淆脚本或资源路径，例如 `/assets/app/scripts/swa-common.js`、`/resources/<hash>`、`/resources/<hash>/e_<id>_<version>.js`
- 请求链出现 `ponos.zeronaught.com`、JWKS/config/telemetry 前置请求，随后业务 API 自动携带 Shape headers
- ruyitrace / domtrace / jscall 中出现 `Request.get headers` 后连续 `Headers.set("prefix-f/b/c/d/z/a", ...)`
- 业务代码只发普通 `fetch` / `XMLHttpRequest`，但浏览器最终请求自动注入 Shape headers
- 去掉任意一个 Shape header 后返回风控错误，例如 `403050700`，完整 headers 才返回业务数据
- 运行链出现 VMP/WASM、Blob Worker、`Function.prototype.toString.call(fn)`、结构化克隆、原型/descriptor/stack 检测等强反补环境行为

读取：
- `references/products/f5_shape.md`

## google_recaptcha_v3

命中特征：
- 页面加载 `https://www.google.com/recaptcha/api.js?render=...` 或 `https://www.recaptcha.net/recaptcha/api.js?render=...`
- 页面调用 `grecaptcha.execute(sitekey, {action})` 或 `grecaptcha.enterprise.execute(sitekey, {action})`
- 请求链出现 `/recaptcha/api2/anchor`、`/recaptcha/api2/reload`、`/recaptcha/enterprise/anchor`、`/recaptcha/enterprise/reload`
- reload 响应体前缀为 `)]}'`，响应数组中出现 `"rresp"`
- 最终业务请求提交 `g-recaptcha-response`、`recaptchaToken`、`recaptcha_response` 或同义 token 字段
- 验证或业务响应出现 `success`、`score`、`action`、`challenge_ts`、`hostname`、`error-codes`
- 用户目标描述为 Google v3、无感验证码、invisible reCAPTCHA、v3 score 或 score 阈值

读取：
- `references/products/google_recaptcha_v3.md`

## jd_jcap_slider

命中特征：
- `jd_jcap` 链路中出现 `tp=30`、`tp=26`、`b1/b2`、`rotate_img`、`drag_box`、`slider`、`slide_path`
- proof 或调试记录出现 `ht/wt/bw/sw/mw/list/ii`、`bw/sw/track/list/ii`、`touchList`、`rec/fpt`
- 需要区分 trace 成功样本和当前在线动态生成成功
- 需要排查 `code=16807`、offset 偏差、视觉 API angle/offset、同 VM bridge 和 split runtime 差异

读取：
- `references/products/jd_jcap_slider.md`
- 同时读取 `references/products/jd_jcap.md`

## perimeterx_px

命中特征：
- Cookie、响应体、脚本、Header、URL 或日志中出现 `_px3`、`_pxvid`、`pxcts`、`_pxAppId`、`pxvid`、`PXu`、`PXZ`、`PX` captcha
- 响应体或 captcha context 中出现 `jsClientSrc`、`collector`、`uuid`、`vid`、`did`、`hostUrl`、`blockScript`、`altBlockScript`、`firstPartyEnabled`
- 请求链出现 `px-cloud.net`、`collector-*.px-cloud.net/api/v2/collector`、`/assets/js/bundle`、`/api/v2/collector`、`/ns`、`/d/p`
- PX collector 或 bundle 响应中出现 `do`、`ob`、set-cookie 命令形态，或 OB 解码后包含 `_px3/_pxvid/pxcts`
- 页面或运行链出现 PerimeterX / HUMAN Security SDK、PX captcha iframe、`collector-notouch`、`bundle-press`、`blocked-page-press`、`xhr-press`
- Walmart 链路出现 `PXu6b0qd2S`、`PXZiTus4E5`、`www.walmart.com`、`advertising.walmart.com`、`identity.walmart.com` 相关 PX block
- 失败响应同时可能出现 Akamai、GraphQL/business 或下游风控结构时，必须先判门，不得把非 PX 拦截误判为 `_px3` 算法问题
- HTTP `200` GraphQL JSON 中的 operation 业务错误码，例如 `SOMETHING_WENT_WRONG`，以及空的 OTP/MFA 字段名，不等于 PX 失败或已进入验证码页

读取：
- `references/products/perimeterx_px.md`
- 如果同链路还出现 `_abck`、`bm_sv`、`ak_bmsc`、Akamai/Bot Manager 标记，同时读取 `references/products/akamai.md`

## ruishu_rs6

命中特征：
- 首次业务页或入口页返回 `412`，随后加载伪装成站点一方资源的动态脚本，例如 `/jhKGIvczkKbR/<random>.0515a6f.js`
- HTML 中存在 `r='m'` 的 `meta` 或内联脚本，常见 `meta id="2vmka0flZgDo"`，其 `content` 会参与动态 JS 环境
- Cookie 中出现同一随机前缀的 `O/P/enable` 组合，例如 `UA1L1zGonajvO`、`UA1L1zGonajvP`、`enable_UA1L1zGonajv`
- 业务 XHR/fetch URL 被自动追加动态 query 后缀，例如 `XJlCTRRM=<119 chars>`
- ruyitrace 来自 Firefox/Gecko 时，必须按 Firefox descriptor/domtrace 补环境，不要默认补 Chrome/WebKit 指纹
- `window.ActiveXObject` 需要显式存在且值为 `undefined` 时，按瑞数/瑞树特征处理
- 最终验收必须是真实业务接口返回 HTTP `200` 和业务数据，不只看 cookie 或后缀生成

读取：
- `references/products/ruishu_rs6.md`
