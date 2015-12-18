
# This is the server logic for a Shiny web application.
# You can find out more about building applications with Shiny here:
#
# http://shiny.rstudio.com
#

library(shiny)
library(raster)
library(rgdal)
library(ggvis)
library(geosphere)
library(countrycode)
library(dplyr)

setwd("~/Projects/koala")

shinyServer(function(input, output, session) {
  initial_country <- "BGD"
  initial_zoom <- 7
  
  palette_names <- sort(rownames(brewer.pal.info))
  
  country <- reactiveValues(code = NA)
  mouse_coordinates <- reactiveValues(lat = 0, lng = 0)
  
  progress <- shiny::Progress$new(session)
  on.exit(progress$close())
  
  progress$set(message = "Loading Natural Earth dataset")
  countries <- readOGR("./datasets/natural_earth", "ne_50m_admin_0_countries")  
  
  progress$set(message = "Loading Population dataset")
  population_data <- raster("./datasets/gpw/gldens00/glds00ag/w001001.adf")
  
  progress$set(message = "Loading GeoEPR dataset")
  population_groups <- readOGR("./datasets/geoEPR/2014", "GeoEPR-2014")
  
  progress$set(message = "Loading Night Lights dataset")
  nightlight_data <- raster("./datasets/noaa/F152000.v4/F152000.v4b_web.stable_lights.avg_vis.tif")
  
  color_palette <- reactive({
    #colorNumeric(c(input$palette_R, input$palette_G, input$palette_B), c(0,100), na.color = "transparent")
    #colorNumeric(c(input$palette_R, "#0C2C84", "#41B6C4", "#FFFFCC"), c(0,100), na.color = "transparent")
    #colorNumeric(c(input$palette_R, "#0C2C84", "#41B6C4", "#FFFFCC"), c(0,100))
    input$palette
  })
  
  spatial_data <- reactive({ 
    if (is.na(country$code))
      return()
    subset(countries, iso_a3 == country$code)
  })

  country_name <- reactive({
    if (is.na(country$code))
      return("")
    sprintf("%s (%s)", spatial_data()$name, country$code)
  })  
  
  extent_obj <- reactive({ 
    if (is.na(country$code))
      return()
    extent(spatial_data()) 
  })

  population_masked <- reactive({ 
    if (is.na(country$code))
      return()
    cropped_obj <- crop(population_data, extent_obj())
    mask(x = cropped_obj, mask = spatial_data()) 
  })
  
  population_obj <- reactive({ 
    if (is.na(country$code))
      return()
    if (input$grid_scale == 1)
      return(population_masked())
    
    aggregate(population_masked(), input$grid_scale)
  })
  
  nightlight_masked <- reactive({ 
    if (is.na(country$code))
      return()
    cropped_obj <- crop(nightlight_data, extent_obj())
    mask(x = cropped_obj, mask = spatial_data()) 
  })

  nightlight_obj <- reactive({ 
    if (is.na(country$code))
      return()
    resample(nightlight_masked(), population_obj())
  })
    
  groups_obj <- reactive({
    cow_code <- countrycode(country$code, "iso3c", "cown")
    population_groups[population_groups$gwid == cow_code,]
  })
  
  render_map <- function(map_id) {
    ext <- extent(subset(countries, iso_a3 == initial_country))
    pol <- rbind(c(ext@xmax, ext@ymax), c(ext@xmax, ext@ymin), c(ext@xmin, ext@ymin), c(ext@xmin, ext@ymax))
    
    center <- centroid(pol)

    leaflet() %>%
      addTiles(
        urlTemplate = "//{s}.tiles.mapbox.com/v4/altaf-ali.98591aaf/{z}/{x}/{y}.png?access_token=pk.eyJ1IjoiYWx0YWYtYWxpIiwiYSI6ImNpZ2xoZGI2NTAwOXV2eG00MHlrd3BnNjIifQ.qOEihbpCyME9-vG4YxLGqw",
        attribution = 'Maps by <a href="http://www.mapbox.com/">Mapbox</a>'
      ) %>%
      addPolygons(data = countries, layerId = ~iso_a3, weight = 0, fillColor = "transparent") %>%
      setView(lng = center[1], lat =  center[2], zoom = initial_zoom) 
  }
  
  output$status_bar <- renderText({ 
    sprintf("%s: %2.2f, %2.2f", mouse_coordinates$id, mouse_coordinates$lat, mouse_coordinates$lng) 
  })
  
  observeEvent(input$population_map_shape_mouseover, { update_coordinates(input$population_map_shape_mouseover) })
  
  observeEvent(input$nightlight_map_shape_mouseover, { update_coordinates(input$nightlight_map_shape_mouseover) })
  
  update_coordinates <- function(event) {
    if(is.null(event))
      return()
    
    mouse_coordinates$id <- event$id
    mouse_coordinates$lat <- event$lat
    mouse_coordinates$lng <- event$lng
  }

  observe({ 
    updateSelectInput(session = session, "palette", selected = palette_names[input$palette_slider])
  })
  
  observe({ 
    updateSliderInput(session = session, "palette_slider", value = which(palette_names == input$palette)[1])
  })
  
  #   zoom <- function(map, zoom_level) {
# #     if (current_view$zoom == zoom)
# #       return()
# # 
# #     view <- rbind(c(current_view$east, current_view$north),
# #                   c(current_view$east, current_view$south),
# #                   c(current_view$west, current_view$south),
# #                   c(current_view$west, current_view$north))
# #     
# #     if (all(view == 0))
# #       return()
# #      
# #     map_center <- centroid(view)
# #     current_view$zoom <- zoom
# #     
#     leafletProxy(map, session = session) %>%
#       leaflet::sync("nightlight_map") %>%
#       setView(lng = 0, lat = 0, zoom = zoom_level)
#   }
  
  output$population_map <- renderLeaflet({ render_map("population_map") })

  output$nightlight_map <- renderLeaflet({ render_map("nightlight_map") })
  
  leafletProxy("population_map", session = session) %>%
    sync("nightlight_map")

  leafletProxy("nightlight_map", session = session) %>%
    sync("population_map")
  
  data_modeler <- reactive({
    if (is.na(country$code)) 
      return(data.frame(population = integer(), nightlight =  integer()))
    
    data.frame(population = values(population_obj()), nightlight =  values(nightlight_obj()))
  })
  
  output$console <- renderText({ 
    if (is.na(country$code)) 
      return()
      
    #grids <- as(population_obj(), 'SpatialPolygonsDataFrame')
    #groups_transformed <- spTransform(groups_obj(), crs(grids))
    
    #a = over(grids, groups_transformed)
    a = list()
    
    sprintf("population: %s, nightlight: %s, groups: %s",
            length(na.omit(values(population_obj()))),
            length(na.omit(values(nightlight_obj()))),
            length(a)
    )
  })

  reactive({
    data_modeler %>%
      ggvis(x = ~population, y = ~nightlight) %>%
      add_axis("x", orient = "top", ticks = 0, title = country_name(),
               properties = axis_props(
                 axis = list(stroke = "white"),
                 labels = list(fontSize = 0))) %>%
      add_axis("x", title = "Population") %>%
      scale_numeric("x", nice = TRUE)  %>%
      add_axis("y", title = "Nightlight") %>%
      scale_numeric("y", nice = TRUE)  %>%
      layer_points(stroke := "black", size = 0.2, fill := "gray") %>%
      set_options(height = map_height, width = "auto")
  }) %>%
  bind_shiny("plot")

  observeEvent(input$population_map_shape_click, { 
    event <- input$population_map_shape_click    
    
    if(is.null(event))
      return()
    
    country$code <- event$id
  })
  
  observe({
    if (is.na(country$code))
      return()
    
    withProgress(message = "Updating Population map", {
      leafletProxy("population_map", session = session) %>%
        clearGroup(group = "population") %>%
        addRasterImage(population_obj(), colors = color_palette(), opacity = 0.8, group = "population")      
    })
  })
  
  observe({
    if (is.na(country$code))
      return()
    
    withProgress(message = "Updating NightLight map", {
      leafletProxy("nightlight_map", session = session) %>%
        clearGroup(group = "nightlight") %>%
        addRasterImage(nightlight_obj(), colors = color_palette(), opacity = 0.8, group = "nightlight")      
    })
  })
  
  build_raster_table <- function(obj) {
    ext <- extent_obj()
    val <- values(obj)
    dataframe <- data.frame(class = class(population_obj), 
                            dimensions = sprintf("%s, %s, %s (nrow, ncol, ncell)", nrow(obj), ncol(obj), ncell(obj)),
                            resolution = sprintf("%s, %s (x, y)", res(obj)[1], res(obj)[2]),
                            extent = sprintf("%s, %s, %s, %s (xmin, xmax, ymin, ymax)", ext@xmin, ext@xmax, ext@ymin, ext@ymax),
                            coord.ref = projection(obj),
                            data.source = "in memory",
                            names = names(obj)[1],
                            values = sprintf("%s, %s (min, max)", min(val, na.rm = TRUE), max(val, na.rm = TRUE))
    )
    t(dataframe)
  }
  
  output$raster <- renderTable({
    if (is.null(population_obj()) || is.null(nightlight_obj()))
      return()
    
    raster_table <- cbind(build_raster_table(population_obj()), build_raster_table(nightlight_obj()))
    colnames(raster_table) <- c("Population", "Night Light")
    raster_table
  })
  
  output$groups <- renderTable({
    groups_obj()@data
  })
  
  #   observe({
#     if (is.na(country$iso3c))
#       return()
#     
#     cat("crop ...")
#     country$cropped_obj <- crop(nightlights, extent(country$polygons))
#     cat("OK\n")
#     
#     cat("mask ...")
#     country$masked_obj <- mask(x = country$cropped_obj, mask = country$polygons)
#     cat("OK\n")
#   })
#   
#   observe({
#     cat("reactive: ENTER ...\n")
#     if (is.null(country$cropped_obj) || is.null(country$masked_obj))
#       return()
#     
#     color_palette <- colorNumeric(palette = input$palette, domain = values(country$cropped_obj), na.color = "transparent")
#     
#     leafletProxy("nightlight_map", session = session) %>%
#       clearGroup(group = "nightlight") %>%
#       addRasterImage(country$masked_obj, colors = color_palette, opacity = 0.8, group = "nightlight")
#     cat("reactive: END ...\n")
#   })
# 
#   observeEvent(input$population_map_shape_mouseover, { 
#     event <- input$population_map_shape_mouseover
#     
#     if(is.null(event))
#       return()
#     
#     country$position <- sprintf("%s:\n  lat = %2.2f\n  lng = %2.2f\n", event$id, event$lat, event$lng)
#   })

#   
#   observeEvent(input$nightlight_map_zoom, { zoom("population_map", input$nightlight_map_zoom) })
  
#   observeEvent(input$population_map_bounds, { 
#     set_bounds("nightlight_map", input$population_map_bounds)
#   })
#   
#   observeEvent(input$nightlight_map_bounds, { 
#     current_view$src <- "nightlight_map"
#     set_bounds("population_map", input$nightlight_map_bounds) 
#   }, priority = 2)
# 
#   set_bounds <- function(map, bounds) {
# #     if (current_view$src == map)
# #       return()
# #     print(sprintf("setting bounds for %s (%s, %s, %s, %s)", map, bounds$east, bounds$west, bounds$north, bounds$south))
# #     
#     leafletProxy(map, session = session) %>%
#       fitBounds(lng1 = bounds$east, lat1 = bounds$north, lng2 = bounds$west, lat2 = bounds$south)
#   }
#   
#   xset_bounds <- function(map, bounds) {
#       if (current_view$dest == map)
#         return()
#     
#     current_view$dest <- map
#     
#       if (bounds$east == current_view$east && bounds$west == current_view$west && bounds$north == current_view$north && bounds$south == current_view$south)
#         return()
#       
#       if (bounds$east < -360 || bounds$west < -360 || bounds$east > 360 || bounds$west > 360)
#         return()
#       
#       if (bounds$north < -180 || bounds$south < -180 || bounds$north > 180 || bounds$south > 180)
#         return()
#       
#       print(sprintf("setting bounds for %s (%s, %s, %s, %s)", map, bounds$east, bounds$west, bounds$north, bounds$south))
#       
#       current_view$north <- bounds$north
#       current_view$east <- bounds$east
#       current_view$south <- bounds$south
#       current_view$west <- bounds$west
#       
#       view <- rbind(c(current_view$east, current_view$north),
#                     c(current_view$east, current_view$south),
#                     c(current_view$west, current_view$south),
#                     c(current_view$west, current_view$north))
#       
#       if (all(view == 0))
#         return()
#       
#       map_center <- centroid(view)
#       
#       leafletProxy(map, session = session) %>%
#         setMaxBounds(lng1 = bounds$east, lat1 = bounds$north, lng2 = bounds$west, lat2 = bounds$south)
#   }
  
})
