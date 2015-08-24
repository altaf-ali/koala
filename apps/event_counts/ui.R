library(shiny)
library(dplyr)
library(data.table)

countries_csv = "http://www.ucl.ac.uk/~uctqiax/escalation/data/countries.csv"
countries = read.csv(countries_csv)

countries$index = rownames(countries)
rownames(countries) <- countries$Country

# Define UI for application that draws a histogram
shinyUI(
  #fluid layout
  fluidPage(
    
    # Application title
    titlePanel("ICEWS Dataset - Rebel & Insurgent Activity"),
  
    # Sidebar with a slider input for the number of bins
    sidebarLayout(
      sidebarPanel(
        selectInput('country', 'Country', rownames(countries)),
        hr(),
        helpText("ICEWS Dataset from 1995-2014")
      ),

      # Show a plot of the generated distribution
      mainPanel(
        plotOutput("timeline")
      )
    )
  )
)
