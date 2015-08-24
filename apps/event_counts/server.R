library(shiny)
library(dplyr)
library(ggplot2)
library(zoo)
library(scales)

events_csv = "http://www.ucl.ac.uk/~uctqiax/escalation/data/events.csv"

events = read.csv(events_csv)

df <- tbl_df(events)
df <- rename(df, Country = CountryAbbr)

# Define server logic required to draw a histogram
shinyServer(function(input, output) {
  
  output$timeline <- renderPlot({
    subset <- df %>%
                filter(Country == input$country) %>%
                mutate(Date = as.Date.yearmon(Year, Month))
    
    ggplot(subset, aes(Date, IncidentDays)) + 
      geom_line() +
      xlab("") +
      ylab("Active Days") +
      scale_x_date(breaks = date_breaks("18 months"), labels = date_format("%b-%y"))
  })
})



