# Mermaid Diagram Initial Position Configuration Examples

This document shows examples of how to configure the initial position of the mermaid diagram in `project_management_model.qmd`.

## Configuration Location

In `project_management_model.qmd`, find the "CONFIGURATION" section (around line 200):

```javascript
initialScale = 0.5  // Start at 50% zoom
initialPanX = 0     // Start at left edge (0px offset)
initialPanY = 0     // Start at top edge (0px offset)
```

## Example Configurations

### Default (Current)
Start at top-left corner with 50% zoom:
```javascript
initialScale = 0.5
initialPanX = 0
initialPanY = 0
```

### Centered View
Start with the diagram more centered and zoomed in:
```javascript
initialScale = 0.7
initialPanX = 200
initialPanY = 100
```

### Focus on Motivation Section
Start zoomed in on the top motivation section:
```javascript
initialScale = 1.0
initialPanX = 50
initialPanY = 50
```

### Overview Mode
Start fully zoomed out to see entire diagram:
```javascript
initialScale = 0.3
initialPanX = 0
initialPanY = 0
```

### Focus on Bottom Sections
Start viewing the lower part of the diagram:
```javascript
initialScale = 0.6
initialPanX = 100
initialPanY = -300  // Negative values pan upward
```

## Parameter Guide

- **initialScale**: Controls zoom level
  - Range: 0.1 (very zoomed out) to 3.0 (very zoomed in)
  - Default: 0.5 (50% zoom)
  - 1.0 = 100% zoom (original size)

- **initialPanX**: Controls horizontal position
  - Positive values: diagram shifts right (shows left part)
  - Negative values: diagram shifts left (shows right part)
  - 0 = no horizontal shift

- **initialPanY**: Controls vertical position
  - Positive values: diagram shifts down (shows top part)
  - Negative values: diagram shifts up (shows bottom part)
  - 0 = no vertical shift

## How the Reset Button Works

The "↺ Reset" button will return the diagram to whatever initial values you configure. So if you set:
```javascript
initialScale = 0.7
initialPanX = 200
initialPanY = 100
```

Then clicking Reset will return to that position, not to (0, 0, 0.5).

## Testing Your Configuration

1. Edit the values in `project_management_model.qmd`
2. Render the site locally with `quarto render` or push to see changes on GitHub Pages
3. The diagram should start at your configured position
4. Pan and zoom controls should still work normally
5. Reset button should return to your configured initial position
