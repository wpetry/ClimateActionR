library(shiny)
library(ggplot2)
library(magrittr)
library(dplyr)

station_yearly_flows <-
  read.csv("~/catdata/station_yearly_flows.csv") %>% 
  filter(Scenario=="rcp26")
station.coords <- read.csv("~/catdata/station_coords.csv") # unique(flow_data[, c("long", "lat")])
theme_set(theme_minimal())
state_shapes <- read.csv("~/catdata/state_shapes.csv")
states <- geom_path(data=state_shapes,
                    aes(group=group))

US.use <- 3e5 # i just made this up
mexico.use <- 2e4 # and this too
shinyServer(function(input, output) {
  mexicoWaterReactive <- reactive({
    store.rate <- input$damStorageRate
    damSize <- input$damSize
    pad <- input$share
    inflow <- station_yearly_flows$streamflow 
    N <- length(inflow)
    ## calculate outflow at each time point
    outflow <- c(0)
    damLevel <- c(0) # start with no water. new dam.
    for (year in 2:N){
      last.year <- year - 1
      store <- store.rate * inflow[year]
      ## check whether there is enough remaining capacity
      if (damLevel[last.year] + store < damSize){
        damLevel[year] <- damLevel[last.year] + store
        outflow[year] <- inflow[year] - store
      } else { ## in this case, the dam is close to full
        damLevel[year] <- damSize
        outflow[year] <- damLevel[last.year] + inflow[year] - damSize
      }
      if (pad) {
        ## if we are at more than 20% of capacity
        ## and mexico needs more water, send some more water
        ## but always keep at least 20% for ourselves
        if (damLevel[year] > 0.2*damSize & outflow[year] < mexico.use) {
          padding <- min(damLevel[year] - 0.2*damSize, mexico.use - outflow[year])
          outflow[year] <- outflow[year] + padding
          damLevel[year] <- damLevel[year] - padding
        }
      }
    }
    outflow
  })
  
  output$stationMap <- renderPlot({
    ggplot(station.coords, aes(long, lat)) + 
      geom_point(size=3, colour="red") + states
  })
  
  output$waterTreatySummary <- renderText({
    mexico.flow <- mexicoWaterReactive()
    N <- nrow(station_yearly_flows )
    prop.years.fail <- sum(mexico.flow < mexico.use)/N
    sprintf("In %.2f%% of years between 1950 and 2100, there is
            not enough water
            remaining for Mexio.", 
            prop.years.fail * 100)
  })
  
  output$flowTimeSeriesPlot <- renderPlot({
    ggplot(station_yearly_flows, aes(Year, streamflow)) + 
      geom_line()
  })
  
  output$mexicoFlowTimeSeriesPlot <- renderPlot({
    station_yearly_flows$outflow <- mexicoWaterReactive()
    ggplot(station_yearly_flows, aes(Year, outflow)) + 
      geom_line() + 
      geom_point(aes(colour=outflow>=mexico.use)) +
      geom_hline(yintercept = mexico.use)
  })
})