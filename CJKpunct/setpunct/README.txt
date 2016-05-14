修改 CJKpunct.spa

  打开文件 setpunct\setpunct-main.tex, 

  1. 根据操作系统修改 \ghostscript 的定义

  2. 修改 \setpunctfamilies, 添加你所使用的CJKfamily

  3. 对于miktex, 运行
     
        latex --enable-write18 setpunct-main
   
     对于texlive, 运行
     
        latex --shell-escape setpunct-main

  4. 把文件 CJKpunct.spa 复制到 CJKpunct.sty 所在文件夹, 然后运行
  
        Texhash   

  ------ 安装完成
 