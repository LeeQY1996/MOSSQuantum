# 构建与维护文档

## 本地预览

在本仓库根目录执行（Python 3.11+）：

```sh
python3 -m venv .docs-env
.docs-env/bin/python -m pip install -r docs/requirements.txt
.docs-env/bin/python docs/build_site.py --output _site
python3 -m http.server 8000 --directory _site
```

打开 `http://localhost:8000/`。构建不加载 Julia，不需要 GPU 或 PySCF。只有文档渲染依赖，版本固定在 `docs/requirements.txt`。函数示例的数值验证须另用对应 Julia 环境，静态构建通过不能替代运行时测试。

## 内容与校验

`docs/api.md` 为索引，`docs/api/` 为函数参考，`docs/site.json` 声明导航及 Markdown 输入。仓库现有专题指南也会渲染。指向源代码、未编入网站的记录和目录的链接跳转同一仓库默认分支；本地 Markdown 页面链接转为 HTML，并检查目标及锚点。源码中的显式 `id` 锚点会保留。

修改公开 API 时同步更新条目中的签名、参数默认值、返回值、变更行为和限制。代码示例应小且可重复；不要在文档构建运行大型扫描或硬件任务。新增文档页时检查导航和相对链接。构建器在失效本地链接或锚点时以非零状态退出。

## GitHub Pages

`.github/workflows/docs.yml` 在默认分支的文档变更时构建、校验、上传并部署到 GitHub Pages。拉取请求只构建，不发布。手工重建可从 Actions 的 Documentation 工作流选择 Run workflow。仓库 Pages 设置使用 GitHub Actions；无需写入 gh-pages 分支或保存生成的 HTML。

站内搜索索引随构建生成，搜索在浏览器中执行。站点不依赖第三方搜索服务。
