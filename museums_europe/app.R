library(shiny)
library(leaflet)
library(shinyjs)
library(dplyr)
library(tidyr)
library(xlsx)
library(ggplot2)
library(DT)
library(readr)


file <- "CCEM.xlsx"
islands_file <- "islands.csv"
  
  
zoom <- 4
lon <- 8
lat  <- 52

mb_map <- "https://api.mapbox.com/styles/v1/mapbox/streets-v10/tiles/256/{z}/{x}/{y}?access_token=pk.eyJtest <- 1IjoibmV4dXNtYXBzIiwiYSI6ImNqNDVsc3M0ajFwMDMyd214OTBtYjNzajkifQ.Yv2nc8LaMpsCHin1x-DIqQ"
mb_sat <- "https://api.mapbox.com/styles/v1/mapbox/satellite-v9/tiles/256/{z}/{x}/{y}?access_token=pk.eyJ1IjoibmV4dXNtYXBzIiwiYSI6ImNqNDVsc3M0ajFwMDMyd214OTBtYjNzajkifQ.Yv2nc8LaMpsCHin1x-DIqQ"

museum_data <- read.xlsx( file = file, 1)
  islands <- read_csv(islands_file, cols(
    lat = col_double(),
    long = col_double(),
    island = col_character(),
    code_patrick = col_character(),
    size = col_integer()
  ), col_names = TRUE) %>% 
    mutate(origin_size = size)


museum_data_mut <- museum_data %>%
  mutate(musid = 1:nrow(.)) %>%
  mutate(Museum.name = as.character(Museum.name)) %>%
  mutate(type = as.character(Content)) %>%
  mutate(type = gsub(".*[^a-zA-Z].*", "Mixed", type, perl = TRUE)) %>%
  mutate_all(funs(gsub("â€™", "'", (.)))) %>%
  mutate_all(funs(gsub("Ã¶", "ö", (.)))) %>%
  mutate_all(funs(gsub("Ã¨", "è", (.)))) %>%
  mutate_all(funs(gsub("Ã¼", "ü", (.)))) %>%
  mutate_all(funs(gsub("Ã³", "ó", (.)))) %>%
  mutate_all(funs(gsub("Ã©", "é", (.)))) %>%
  mutate_all(funs(gsub("Ã", "í", (.)))) %>%
  mutate_all(funs(gsub("Ã", "ss", (.)))) %>%
  mutate_all(funs(gsub("Ã¡", "á", (.)))) %>%
  mutate_all(funs(gsub("Ã¤", "ä", (.)))) %>%
  mutate_all(funs(gsub("ÃŸ", "ss", (.)))) %>%
  mutate_all(funs(gsub("à ¤", "ä", (.)))) %>%
  mutate(owner_course = as.character(Ownership)) %>%
  mutate(Languages = as.character(Languages)) %>%
  mutate(owner_course = gsub("-", "None", as.character(owner_course))) %>%
  mutate(Languages = gsub("-", "None", as.character(Languages))) %>%
  separate(Coordinates, c("latitude", "longitude"), ", ")  %>%
  mutate(latitude = as.numeric(latitude)) %>%
  mutate(longitude = as.numeric(longitude)) %>%
  mutate(id = 1:nrow(.)) %>%
  arrange(id) %>%
  mutate(icon_col = paste0(substr(tolower(type), 1, 3), "_", substr(tolower(owner_course), 1, 3)))

museum_data_unnested <- museum_data_mut %>%
  mutate(Collecting.period = gsub(" ?\\([^\\(]+\\) ?", "", Collecting.period)) %>%
  mutate(Collecting.period = strsplit(as.character(Collecting.period), "\n")) %>% 
  mutate(Collection.origins = gsub(" & ", " and ", Collection.origins)) %>%
  mutate(Collection.origins = strsplit(as.character(Collection.origins), "\n")) %>% 
  mutate(objects = gsub("\\([^(]+\\)", "", Types.of.objects, perl = TRUE)) %>%
  mutate(objects = gsub("plants", "Plants", objects, perl = TRUE)) %>%
  mutate(objects = gsub("coral", "Coral", objects, perl = TRUE)) %>%
  mutate(objects = gsub("Others.*", "Other", objects, perl = TRUE)) %>%
  mutate(objects = gsub("/", "\n", objects, perl = TRUE)) %>%
  mutate(objects = strsplit(as.character(objects), "\n")) %>% 
  mutate(type = gsub("Mixed.*", "Mixed", type, perl = TRUE)) %>%
  mutate(type = ifelse(is.na(type),"None", type)) %>%
  mutate(Collecting.period = ifelse(is.na(Collecting.period),"Unknown", Collecting.period)) %>%
  mutate(Collection.origins = ifelse(is.na(Collection.origins),"Unknown", Collection.origins)) %>%
  mutate(objects = ifelse(is.na(objects),"Unknown", objects)) %>%
  unnest(Collecting.period, .drop= FALSE) %>%
  unnest(Collection.origins, .drop= FALSE) %>%
  mutate(Collection.origins = gsub("^Caribbean", "Unknown", Collection.origins)) %>%
  unnest(objects, .drop= FALSE) %>%
  filter(objects != "") %>%
  left_join(islands, by = c("Collection.origins" = "island"))

  

convcol <- colorFactor(c("navy", "brown", "red", "green", "brown", "yellow"), domain = c("Archaeology", "Art", "Ethnography", "History", "Mixed", "None"))
convsize <- function(x){nchar(as.character(x))*3 + 1}

reorder_values <- function(x){
  move_to_end <- c ("Other", "Unknown")
  stripped <- x[! x %in% move_to_end]
  cat(stripped)
  x <- c(stripped, move_to_end)
}


types <- sort(unique(museum_data_unnested$type)) %>% reorder_values()
periods <- sort(unique(museum_data_unnested$Collecting.period)) %>% reorder_values()
origins <- sort(unique(museum_data_unnested$Collection.origins))%>% reorder_values()
objects <- sort(unique(museum_data_unnested$objects)) %>% reorder_values()


ui <- shinyUI(fluidPage(
  tags$head(
    tags$style(HTML("
                    .form-group {
                      space-before: none;
                    }
                    
                    "))
  ),
  shinyjs::useShinyjs(),  
  
  titlePanel("Caribbean collections in Europe"),
  
  fluidRow(
    
    
    column(6,
           htmlOutput("copyright")
    )
  ),  
  
  fluidRow(
    
    column(6,
           leafletOutput("map")
    ),       
    column(3,
           wellPanel(height = 100, 
                     
                     h4("Info"),
                     htmlOutput("museum_info")
           )
    )   
  ),
  
  fluidRow(
    
    column(6,
           htmlOutput("legend")
    )
    
  ),
  
  fluidRow(
    
    column(2, 
           radioButtons("toggle_objects", "Objects", choices = c("all", "none", "choose"), selected = "choose", inline = TRUE),
           checkboxGroupInput("objects",
                              "",
                              choices = objects,
                              selected = objects
           )   
    ),
    
    column(2,
           radioButtons("toggle_period", "Collecting period", choices = c("all", "none", "choose"), selected = "choose", inline = TRUE),
           checkboxGroupInput("period",
                              "",
                              choices = periods,
                              selected = periods
           )
    ),       
    column(2,
           radioButtons("toggle_origin", "Collection origin", choices = c("all", "none", "choose"), selected = "choose", inline = TRUE),
           checkboxGroupInput("origin",
                              "",
                              choices = origins,
                              selected = origins
           )         
    ),
    

    
    
    # column(3,
    #        dataTableOutput('list')
    #        
    # )
    
    
    column(3,
      wellPanel(height = 100, 
                     
            h4("Collection origins"),
           leafletOutput("source")
        )
    )      
    
  )  
 )   
)






server <- shinyServer(function(input, output, session) {
  
  selected <- museum_data_unnested %>%
    mutate(id = as.numeric(id)) %>%
    arrange(id) 
  
  event_data <- reactiveValues(clickedMarker = NULL)
  
  location <- reactiveValues(lon = lon, lat = lat)
  
  output$museum_info <- renderText({
    paste0("Number of museums: ", length(unique(museum_data_mut$musid)))
    #paste(c(input$type), collapse = "|")    
  })
  
  ids <- c(museum_data_unnested$id)
  
  observeEvent({
    input$objects
    input$period
    input$origin
    input$toggle_objects
    input$toggle_period
    input$toggle_origin
  }, {
    
    selected <- museum_data_unnested %>%
      mutate(id = as.numeric(id)) %>%
      arrange(id) %>%
      filter(grepl(paste(c(input$period, "KOMTNOOITVOOR"), collapse = "|"), Collecting.period), grepl(".*", Collecting.period)) %>%
      filter(grepl(paste(c(input$objects, "KOMTNOOITVOOR"), collapse = "|"), objects), grepl(".*", objects)) %>%
      filter(grepl(paste(c(input$origin, "KOMTNOOITVOOR"), collapse = "|"), Collection.origins), grepl(".*", Collection.origins))
    
    output$museum_info <- renderText({
      paste0("Number of museums selected: <strong>", length(unique(selected$musid)), "</strong><br/>&nbsp;<br/>&nbsp;<br/>&nbsp;<br/>&nbsp;<br/>&nbsp;<br/>&nbsp;<br/>&nbsp;<br/>&nbsp;<br/>&nbsp;<br/>&nbsp;<br/>&nbsp;<br/>&nbsp;<br/>&nbsp;<br/>&nbsp;<br/>&nbsp;<br/>")
    })
    
    output$source <- renderLeaflet({
      
      leaflet(data = selected) %>%
        setView(lng = -72, lat = 14.5, zoom = 4) %>%
        addTiles(group="Base map") %>%
        addCircleMarkers(
          ~long,
          ~lat,
          color = "brown",
          stroke = FALSE,
          fillOpacity = 1,
          radius = 3,
          popup = ~as.character(paste0("<strong>", Collection.origins, "</strong><br>" ))
        )
      
    })  
    
    # output$list <- DT::renderDataTable({
    #   
    #   for_dt <- selected %>%
    #     select(Museum.name) %>%
    #     unique()
    #   
    #   DT::datatable(for_dt, selection = "single", rownames= FALSE)
    # })         
    
    
  } )
  
  
  observe({
    if (input$toggle_objects == "choose") {
      shinyjs::enable("objects")
    } 
    
    else if (input$toggle_objects == "all") {
      updateCheckboxGroupInput(session,"objects", selected=objects)
      shinyjs::disable("objects")
    }
    
    else  {
      updateCheckboxGroupInput(session,"objects", selected="")
      shinyjs::disable("objects")
    }
  })
  
  observe({
    if (input$toggle_period == "choose") {
      shinyjs::enable("period")
    } 
    
    else if (input$toggle_period == "all") {
      updateCheckboxGroupInput(session,"period", selected=periods)
      shinyjs::disable("period")
    }
    
    else  {
      updateCheckboxGroupInput(session,"period", selected="")
      shinyjs::disable("period")
    }
  })
  
  observe({
    if (input$toggle_origin == "choose") {
      shinyjs::enable("origin")
    }
    
    else if (input$toggle_origin == "all") {
      updateCheckboxGroupInput(session,"origin", selected=origins)
      shinyjs::disable("origin")
    }
    
    else  {
      updateCheckboxGroupInput(session,"origin", selected="")
      shinyjs::disable("origin")
    }
  })
  
 
  # observeEvent(input$list_row_last_clicked, {
  #   
  #   
  #   record <- museum_data_mut %>%
  #     filter(musid == as.numeric(input$list_row_last_clicked))
  # 
  #   leafletProxy('map', data = record) %>%
  #     setView(lng = lon, lat = lat, zoom = zoom)
  #   
  #   
  #   museum_name   = record$Museum.name
  #   description   = record$Content
  #   address       = record$Address
  #   country       = record$Country.or.Island
  #   phone         = record$Phone..
  #   website       = paste0( "http://", record$Website)
  #   opening_hours = record$Opening.hours
  #   objects       = record$Types.of.objects
  #   origin        = record$Collection.origin
  #   period        = record$Collecting.period
  #   id            = record$id
  #   
  #   output$museum_info <- renderText({
  #     paste0(
  #       #id, " ",
  #       #input$list_row_last_clicked, " ",
  #       '<strong>', museum_name, '</strong><br/><br/>',
  #       description, '</br/><br/>',
  #       address, " ", country, '<br/>',
  #       'tel: ', phone, '<br/>',
  #       '<a href="', website, '">website</a><br/><br/>',
  #       'Opening hours:<br/>', opening_hours, '<br/><br/>',
  #       '<strong>', 'Objects: ', objects, '</strong>, '<br/>',
  #       '<strong>', 'Collection origin: ', '</strong>, origin, '<br/>',
  #       '<strong>', 'Collecting period: ', '</strong>, period, '<br/>'
  #     )
  #     # 
  #   })
  # })  
  
  observeEvent(input$map_marker_click, {
    
    clicked_id   <- input$map_marker_click$id
    #location$lat  <- input$map_marker_click$lat
    #location$lon <- input$map_marker_click$lng
    
    if(!is.null(input$map_zoom)) { zoom <- input$map_zoom }
    
    
    record <- museum_data_mut %>%
      filter(musid == as.numeric(clicked_id))

    leafletProxy('map', data = record) %>%
      setView(lng = lon, lat = lat, zoom = zoom)
    
    
    museum_name   = record$Museum.name
    description   = record$Content
    address       = record$Address
    country       = record$Country.or.Island
    phone         = record$Phone..
    website       = record$Website
    opening_hours = record$Opening.hours
    objects       = record$Types.of.objects
    origin        = record$Collection.origin
    period          = record$Collecting.period
    id            = record$id
    
    output$museum_info <- renderText({
      paste0(
        #id, " ",
        '<strong>', museum_name, '</strong><br/><br/>',
        description, '</br/><br/>',
        address, " ", country, '<br/>',
        'tel: ', phone, '<br/>',
        '<a href="', website, '">website</a><br/><br/>',
        'Opening hours:<br/>', opening_hours, '<br/><br/>',
        'Objects: ', objects, '<br/>',
        #'Collection origin: ', origin, '<br/>',
        'Collecting period: ', period, '<br/>'
      )
    
    })
    
    output$source <- renderLeaflet({

      sources <- museum_data_unnested %>%
          filter(musid == as.numeric(clicked_id)) %>%
          mutate(lat = as.numeric(lat), long = as.numeric(long))


      leaflet(data = sources) %>%
        setView(lng = -72, lat = 14.5, zoom = 4) %>%
        addTiles(group="Base map") %>%
        addCircleMarkers(
            ~long,
            ~lat,
            color = "brown",
            stroke = FALSE,
            fillOpacity = 1,
            radius = 3,
            popup = ~as.character(paste0("<strong>", Collection.origins, "</strong><br>" ))
        )

    })
    
    
    
  })
  
  output$map <- renderLeaflet({
    
    if(!is.null(input$map_zoom)) { zoom <- input$map_zoom }
    if(!is.null(location$lat)) { lat <- location$lat }
    if(!is.null(location$lon)) { lon <- location$lon }
    
    
    selected <- museum_data_unnested %>%
      mutate(id = as.numeric(id)) %>%
      arrange(id) %>%
      filter(grepl(paste(c(input$objects, "KOMTNOOITVOOR"), collapse = "|"), objects), grepl(".*", objects))  %>%
      filter(grepl(paste(c(input$period, "KOMTNOOITVOOR"), collapse = "|"), Collecting.period), grepl(".*", Collecting.period)) %>%
      filter(grepl(paste(c(input$origin, "KOMTNOOITVOOR"), collapse = "|"), Collection.origins), grepl(".*", Collection.origins)) 
    
    
    leaflet(data = selected) %>%
      setView(lng = lon, lat = lat, zoom = zoom) %>%
      addTiles(group="Base map") %>%
      # addProviderTiles(providers$Stamen.Toner, group ="Black and white") %>%
      #addProviderTiles(providers$Esri.NatGeoWorldMap, group ="Color") %>%
      #addProviderTiles(providers$Esri.WorldImagery, group ="Satellite") %>%
      #addTiles() %>%
      # addTiles(mb_map, group="Base map")  %>%
      # addTiles(mb_sat, group="Satellite")  %>%
      addCircleMarkers(
        ~longitude,
        ~latitude,
        layerId = selected$musid,
        #color = ~convcol(object),
        stroke = FALSE, 
        fillOpacity = 0.5,
        radius = ~convsize(Size.of.Ameridian.archaeological.collection),
        #icon = ~icon_list[icon_col],
        popup = ~as.character(paste0("<strong>", Museum.name, "</strong><br>" ))
        #popup = ~as.character(paste0("<img width = '120px', src= 'http://leidenarch.nl/facades/", Facade, "'/> <br/> <strong>", Museum.name, "</strong><br>" ))
      ) %>%
      addLayersControl(
        baseGroups = c("Base map", "Satellite"),
        options = layersControlOptions(collapsed = FALSE)
      )    
    
  })
  
  
  output$museum_info <- renderText({
    paste0("Number of museums selected: <strong>", length(unique(selected$musid)), "</strong><br/>&nbsp;<br/>&nbsp;<br/>&nbsp;<br/>&nbsp;<br/>&nbsp;<br/>&nbsp;<br/>&nbsp;<br/>&nbsp;<br/>&nbsp;<br/>&nbsp;<br/>&nbsp;<br/>&nbsp;<br/>&nbsp;<br/>&nbsp;<br/>&nbsp;<br/>")
  })
  
  output$legend <- renderText({
    
    "The size of the circle for a museum reflects the size of the Amerindian collection in the museum."
 
  })    
  
  
  output$source <- renderLeaflet({
    
    
    leaflet(data = selected) %>%
      setView(lng = -72, lat = 14.5, zoom = 4) %>%
      addTiles(group="Base map") %>%
      addCircleMarkers(
        ~long,
        ~lat,
        color = "brown",
        stroke = FALSE, 
        fillOpacity = 1,
        radius = 3,
        popup = ~as.character(paste0("<strong>", Collection.origins, "</strong><br>" ))
      ) 
    
  })         

  
  output$copyright <- renderText({
  "Map produced as part of NEXUS1492, an ERC project directed by Corinne Hofman. The data was collected by Mariana de Campos Françoso. Map by Wouter Kool in collaboration with Mereke van Garderen."})
  
  # output$list <- DT::renderDataTable({
  #   
  #   for_dt <- selected %>%
  #     select(Museum.name) %>%
  #     unique()
  #   
  #   
  #   DT::datatable(for_dt, rownames= FALSE)
  # })
  
  
}) 

shinyApp(ui = ui, server = server)
