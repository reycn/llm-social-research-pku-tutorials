In designing / plotting any figures or plots, use `ggplot2` in R to create publication ready plots:

1. Title: use ""; do not use any titles because we are going to add the figure caption in tex files later
2. Subtitle: use ""; do not use any substitles because we are going to add the figure caption in tex files later
3. Theme: `theme_classic()` with small `sans-serif` text
3. Color: prefer Nature style color-blind ready colors for clarity and contrast; such as #0072B2, #D55E00, #009E73 etc
4. Scale: if the variation of one axix is large, use log10 for the axis for clarity; if the figure is comparing effect sizes, use fixed scale range for clarity
5. Theme: use theme_bw by default, do not use theme_minimal
6. Dashed lines: if you have a certain `baseline` to compare, such as the true treatment effects, or baseline control groups, user vertical or horizontal dashed gray line to show it
7. Legend: Compact legends and labels; avoid multiple legends in one graph, i.e., when you defined a variable in both color, type and other simultaneous styles, pefer a legend by color and hide others for clarity
8. Position of Legend: prefer bottom > bottom right outside box > top left / top right inside the box if there's space
9. Wrap: remove the gray backgrounds for each wrap title
10. Panel Labels: bold A/B/C/D panel labels
11. Panel composition: patchwork for panel composition
12. Minimal gridlines and decoration, but for effect sizes plots, use gray 0.3 alpha line of zero for comparison
13. Output: vector PDF plus 320-dpi PNG
