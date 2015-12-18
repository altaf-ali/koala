
# This is the user-interface definition of a Shiny web application.
# You can find out more about building applications with Shiny here:
#
# http://shiny.rstudio.com
#

library(shiny)
library(leaflet)
library(ggvis)
library(RColorBrewer)

setwd("~/Projects/koala")

shinyUI(fluidPage(
  
  includeCSS("apps/grids/www/css/styles.css"),
  
  #tags$head(tags$script(src="main.js")),
  #tags$head(tags$script(src="leaflet.sync/L.Map.Sync.js")),
  
#   fixedPanel(
#     tags$head(includeCSS("apps/grids/css/styles.css")),
#     id = "fullscreen", 
#     top = 0, left = 0, width = "100%", height = "100%",
#     leafletOutput("population_map", width = "100%", height = "100%")
#   )

  fluidRow(
    column(class = "well-panel", width = 4,
           wellPanel(class = "map", leafletOutput("population_map", height = map_height))
    ),
    column(class = "well-panel", width = 4,
           wellPanel(class = "map", leafletOutput("nightlight_map", height = map_height))
    ),
    column(class = "well-panel", width = 4,
           wellPanel(class = "map", ggvisOutput("plot"))
    )
  ),
   
  fluidRow(
    column(width = 2,
           sliderInput("grid_scale", "Grid Scale", 
                       min = 1, 
                       max = 10, 
                       value = 1
                       ),
           
           selectInput("palette", label = "Color Palette", 
                       choices =  sort(rownames(brewer.pal.info)),
                       selected = 1),
           
           sliderInput("palette_slider", label = NULL, 
                       min = 1, 
                       max = nrow(brewer.pal.info), 
                       value = 1,
                       step = 1,
                       animate = animationOptions(interval = 10000)),
           
           verbatimTextOutput("status_bar")
    ),
    
    column(width = 10,
           tabsetPanel(type = "tabs", 
                       tabPanel("Raster", tableOutput("raster")), 
                       tabPanel("Groups", tableOutput("groups")), 
                       tabPanel("Summary", tableOutput("summary")),
                       tabPanel("Console", verbatimTextOutput("console"))
           )
    )
    
#     , column(width = 6,
#            colourInput("palette_R", NULL, "#0C2C84"),
#            colourInput("palette_G", NULL, "#41B6C4"),
#            colourInput("palette_B", NULL, "#FFFFCC")
#     )
  )
))
