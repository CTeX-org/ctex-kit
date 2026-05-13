---
name: answer-question
description: 通用问答, 回答用户咨询、技术探讨等非错误、非功能需求的 Issue。
---

# answer-question

回答用户的通用查询、技术探讨或使用咨询。

> 遵循 `github-comment` 规范。

## 回答原则

**优先**：
- 直接回答问题，不绕弯子
- 引用代码时附带链接
- 不确定时明确说明

**避免**：
- 过于冗长的解释
- 无关的背景信息
- 模棱两可的表述

## 引用代码

涉及代码时，提供准确位置：
- 使用完整 GitHub 链接格式
- 引用关键代码片段（折叠长代码）

## 模板

```markdown
## 💬 回答 #${issue_number}

{直接简洁的回答}

---

<details>
<summary><h3>📖 技术细节</h3></summary>

**相关代码**: [{文件}:{行号}]({github_link})

```{lang}
{代码片段}
```

{补充解释}

</details>
```

无法确定时：
```markdown
## 💬 回答 #${issue_number}

{说明无法确定的原因}

**可能的方向**:
- {方向 1}
- {方向 2}

<details>
<summary><h3>❓ 需要更多信息</h3></summary>

- {需要什么信息才能准确回答}

</details>
```
