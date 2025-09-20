#let my_img(img, width, cap) = {
  figure(
    image(img, width: width),
    caption: [#cap],
    supplement: [图]
  )
}
