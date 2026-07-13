# Issue 972 evidence

- `url-hyperref-right-ecglue.tex`: standalone MWE comparing `\nolinkurl` and
  linked `\url` in a CJK context.
- `url-hyperref-right-master.png`: XeLaTeX output using ctex-kit master
  `1f10b45f` (xeCJK v3.10.3).

The linked URL is 3.33pt narrower than the no-link reference. Direct width
decomposition reports 0pt at the URL-to-CJK right boundary.
