#import "@preview/cjk-unbreak:0.1.1": remove-cjk-break-space
#show: remove-cjk-break-space

#set page(
  paper: "a4",
  header: [
    #rect(
      stroke: (bottom: 0.5pt + black),
    )[#box(height: 32pt, image("img/fm_logo.png")) #h(1fr) 深圳市沣满智能科技有限公司]
  ],
  margin: (x: 1.5cm, y:2.5cm)
)
#set text(font: "Noto Serif CJK SC", size: 11pt)
#set heading(numbering: "1.")

#let title = [Ouster激光雷达原生API编程入门]
#let author = [张佳炜]
#align(center, text(16pt)[*#title*])
#align(center)[#author]
#box(height: 0.5cm)

  Ouster激光雷达为软件访问和控制传感器提供了一些API，并在此基础上
  通过Ouster SDK进行了封装，以便开发者更方便地使用；尽管如此，
  Ouster在其产品手册或帮助文档中公开了这些API的说明和使用方法，
  本文介绍如何在不依赖Ouster SDK的情况下，直接使用底层API访问
  和控制雷达，供研究学习或希望绕过SDK直接使用底层API的用户参考。

  本文的内容适用于Ouster OS0、OS1和OS2硬件版本号Rev06/Rev07，
  固件版本号v2.5.3/v3.0.x/v3.1.x的激光雷达，API操作的代码使用
  C编写，测试使用的传感器型号为OS-1-64 Rev 06，固件版本号为v2.5.3。

#include "http_api.typ"
#include "udp_api.typ"
#include "references.typ"
