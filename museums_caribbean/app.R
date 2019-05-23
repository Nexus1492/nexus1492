library(dplyr)
library(ggplot2)
library(leaflet)
library(shiny)
library(shinyjs)
library(tidyr)
library(xlsx)

file <- "Museum Database Final Final sorted.xlsx"
types_file <- "Museum Types.xlsx"

zoom <- 4
long <- -72
lat  <- 14.5

mb_map <- "https://api.mapbox.com/styles/v1/mapbox/streets-v10/tiles/256/{z}/{x}/{y}?access_token=pk.eyJ1IjoibmV4dXNtYXBzIiwiYSI6ImNqNDVsc3M0ajFwMDMyd214OTBtYjNzajkifQ.Yv2nc8LaMpsCHin1x-DIqQ"
mb_sat <- "https://api.mapbox.com/styles/v1/mapbox/satellite-v9/tiles/256/{z}/{x}/{y}?access_token=pk.eyJ1IjoibmV4dXNtYXBzIiwiYSI6ImNqNDVsc3M0ajFwMDMyd214OTBtYjNzajkifQ.Yv2nc8LaMpsCHin1x-DIqQ"

create_icon_data_frame <- function(){
  
  do <- data.frame(owner=c("Governmental","Grassroots","Private","Mixed","Unknown"),
                   shape=c(22,21,24,23,25))
  
  # Define type colors
  dt <- data.frame(type=c("Archaeology","Art","Built heritage","History","Mixed", "Nature/science","Popular culture"), 
                   color=as.character(c("#e41a1c","#984ea3","#ff7f00","#e8cf14","#377eb8","#4daf4a","#603521")))
  
  # Create cross table for all combinations
  d <- expand.grid(do$owner,dt$type)
  colnames(d) <- c("owner","type")
  d <- merge(d,do)
  d <- merge(d,dt)  
  
  return(d)
}

create_icon_files <- function(d){
  
  #Plot symbols
  for(i in 1:nrow(d)){

    p <- ggplot(d[i,]) + coord_equal()
    p <- p + geom_point(aes(x=0, y=0), color=d$color[i], fill=d$color[i], shape=d$shape[i], size=15)
    p <- p + guides(fill=FALSE, color=FALSE, shape=FALSE)
    p <- p + theme(panel.grid = element_blank(),panel.background = element_blank())
    p <- p + theme(axis.title = element_blank(),axis.text = element_blank(),axis.ticks = element_blank())
    p <- p + theme(axis.line=element_blank(),
            axis.text.x=element_blank(),
            axis.text.y=element_blank(),
            axis.ticks=element_blank(),
            axis.title.x=element_blank(),
            axis.title.y=element_blank(),
            panel.background=element_blank(),
            panel.border=element_blank(),
            panel.grid.major=element_blank(),
            panel.grid.minor=element_blank(),
            plot.background=element_blank(),
            plot.margin=unit(c(0,0,0,0), "cm"),
            panel.margin=unit(c(0,0,0,0), "cm"))

    icon_name <- paste0(substr(tolower(d$type[i]), 1 ,3), "_", substr(tolower(d$owner[i]), 1, 3))
    file_name <- paste0(icon_name, ".png")
    ggsave(p, file = file_name, width = 24, height = 24)

    p

  }

}

create_icons_legend <- function(d){
  
 for(i in 1:nrow(d)){
   
   p <- ggplot(d[i,]) + coord_equal() 
   p <- p + geom_point(aes(x=0, y=0), shape=d$shape[i], size=15)
   p <- p + theme(panel.grid = element_blank(),panel.background = element_blank())
   p <- p + theme(axis.title = element_blank(),axis.text = element_blank(),axis.ticks = element_blank())
   p <- p + theme(axis.line=element_blank(),
                   axis.text.x=element_blank(),
                   axis.text.y=element_blank(),
                   axis.ticks=element_blank(),
                   axis.title.x=element_blank(),
                   axis.title.y=element_blank(),
                   panel.background=element_blank(),
                   panel.border=element_blank(),
                   panel.grid.major=element_blank(),
                   panel.grid.minor=element_blank(),
                   plot.background=element_blank(),
                   plot.margin=unit(c(0,0,0,0), "cm"),
                   panel.margin=unit(c(0,0,0,0), "cm"))    
   
   icon_name <- paste0(substr(tolower(d$owner[i]), 1, 3))
   file_name <- paste0("own_", icon_name, ".png")
   ggsave(p, file = file_name, width = 24, height = 24)
   
   p 
 }
} 


icon_df <- create_icon_data_frame()

#create_icon_files(icon_df)
#create_icons_legend(do)

get_color <- function(type){
  
  return(icon_df$color[icon_df$type == type])
  
  
}


icon_list <- iconList(
  arc_gov = makeIcon("./icons/arc_gov.png", iconWidth = 12, iconHeight = 12),
  arc_gra = makeIcon("./icons/arc_gra.png", iconWidth = 12, iconHeight = 12),
  arc_pri = makeIcon("./icons/arc_pri.png", iconWidth = 12, iconHeight = 12),
  arc_mix = makeIcon("./icons/arc_mix.png", iconWidth = 12, iconHeight = 12),
  arc_unk = makeIcon("./icons/arc_unk.png", iconWidth = 12, iconHeight = 12),
  art_gov = makeIcon("./icons/art_gov.png", iconWidth = 12, iconHeight = 12),
  art_gra = makeIcon("./icons/art_gra.png", iconWidth = 12, iconHeight = 12),
  art_pri = makeIcon("./icons/art_pri.png", iconWidth = 12, iconHeight = 12),
  art_mix = makeIcon("./icons/art_mix.png", iconWidth = 12, iconHeight = 12),
  art_unk = makeIcon("./icons/art_unk.png", iconWidth = 12, iconHeight = 12),
  bui_gov = makeIcon("./icons/bui_gov.png", iconWidth = 12, iconHeight = 12),
  bui_gra = makeIcon("./icons/bui_gra.png", iconWidth = 12, iconHeight = 12),
  bui_pri = makeIcon("./icons/bui_pri.png", iconWidth = 12, iconHeight = 12),
  bui_mix = makeIcon("./icons/bui_mix.png", iconWidth = 12, iconHeight = 12),
  bui_unk = makeIcon("./icons/bui_unk.png", iconWidth = 12, iconHeight = 12),
  his_gov = makeIcon("./icons/his_gov.png", iconWidth = 12, iconHeight = 12),
  his_gra = makeIcon("./icons/his_gra.png", iconWidth = 12, iconHeight = 12),
  his_pri = makeIcon("./icons/his_pri.png", iconWidth = 12, iconHeight = 12),
  his_mix = makeIcon("./icons/his_mix.png", iconWidth = 12, iconHeight = 12),
  his_unk = makeIcon("./icons/mix_unk.png", iconWidth = 12, iconHeight = 12),
  mix_gov = makeIcon("./icons/mix_gov.png", iconWidth = 12, iconHeight = 12),
  mix_gra = makeIcon("./icons/mix_gra.png", iconWidth = 12, iconHeight = 12),
  mix_pri = makeIcon("./icons/mix_pri.png", iconWidth = 12, iconHeight = 12),
  mix_mix = makeIcon("./icons/mix_mix.png", iconWidth = 12, iconHeight = 12),
  mix_unk = makeIcon("./icons/mix_unk.png", iconWidth = 12, iconHeight = 12),
  unk_gov = makeIcon("./icons/unk_gov.png", iconWidth = 12, iconHeight = 12),
  unk_gra = makeIcon("./icons/unk_gra.png", iconWidth = 12, iconHeight = 12),
  unk_pri = makeIcon("./icons/unk_pri.png", iconWidth = 12, iconHeight = 12),
  unk_mix = makeIcon("./icons/unk_mix.png", iconWidth = 12, iconHeight = 12),
  unk_unk = makeIcon("./icons/unk_unk.png", iconWidth = 12, iconHeight = 12),
  pop_gov = makeIcon("./icons/pop_gov.png", iconWidth = 12, iconHeight = 12),
  pop_gra = makeIcon("./icons/pop_gra.png", iconWidth = 12, iconHeight = 12),
  pop_pri = makeIcon("./icons/pop_pri.png", iconWidth = 12, iconHeight = 12),
  pop_mix = makeIcon("./icons/pop_mix.png", iconWidth = 12, iconHeight = 12),
  pop_unk = makeIcon("./icons/pop_unk.png", iconWidth = 12, iconHeight = 12),
  nat_gov = makeIcon("./icons/nat_gov.png", iconWidth = 12, iconHeight = 12),
  nat_gra = makeIcon("./icons/nat_gra.png", iconWidth = 12, iconHeight = 12),
  nat_pri = makeIcon("./icons/nat_pri.png", iconWidth = 12, iconHeight = 12),
  nat_mix = makeIcon("./icons/nat_mix.png", iconWidth = 12, iconHeight = 12),
  nat_unk = makeIcon("./icons/nat_unk.png", iconWidth = 12, iconHeight = 12),
  own_gov = makeIcon("./icons/own_gov.png", iconWidth = 12, iconHeight = 12),
  own_gra = makeIcon("./icons/own_gra.png", iconWidth = 12, iconHeight = 12),
  own_pri = makeIcon("./icons/own_pri.png", iconWidth = 12, iconHeight = 12),
  own_mix = makeIcon("./icons/own_mix.png", iconWidth = 12, iconHeight = 12),
  own_unk = makeIcon("./icons/own_unk.png", iconWidth = 12, iconHeight = 12)
)

museum_data <- read.xlsx( file = file, 1)
types <- read.xlsx( file = types_file, 1)

types_mut <- types %>%
  mutate(Museum.name = as.character(Museum.name)) 
  
museum_data_mut <- museum_data %>%
  mutate(Museum.name = as.character(Museum.name)) %>%
  left_join(types_mut, by = c(Museum.name = "Museum.name")) %>%
  mutate(type = as.character(Museum.TYPE)) %>%
  mutate(owner_course = gsub("[, ].*", "", as.character(Ownership))) %>%
  mutate(owner_course = gsub("NGO", "Grassroots", as.character(owner_course))) %>%
  mutate(type = ifelse(is.na(type),"None", type)) %>%
  mutate(Languages = as.character(Languages)) %>%
  mutate(owner_course = gsub("-", "None", as.character(owner_course))) %>%
  mutate(Languages = gsub("-", "None", as.character(Languages))) %>%
  separate(Coordinates, c("latitude", "longitude"), ", ")  %>%
  mutate(latitude = as.numeric(latitude)) %>%
  mutate(longitude = as.numeric(longitude)) %>%
  mutate(id = 1:nrow(museum_data)) %>%
  arrange(id) %>%
  mutate(icon_col = paste0(substr(tolower(type), 1, 3), "_", substr(tolower(owner_course), 1, 3)))

languages <- c(
  "Creole",
  "Dutch",
  "English",
  "French",
  "Garinagu",
  "German",
  "Hindi",
  "Italian",
  "Kalinago",
  "Papiamento",
  "Russian",
  "Spanish",
  "Swedish", 
  "Unknown",
  "None"
)

owners <- c(sort(unique(museum_data_mut$owner_course)))

types <- c(sort(unique(museum_data_mut$type)))

ui <- shinyUI(fluidPage(
  tags$head(
    tags$style(HTML("
                    .form-group {
                      space-before: none;
                    }
                    
                    "))
    ),
  shinyjs::useShinyjs(),  

  titlePanel("Nexus1492 Museum Survey"),
    
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
               wellPanel(height =100, 
                 
                 h4("Info:"),
                htmlOutput("museum_info")
             )
      )   
    ),
  
  
  fluidRow(
    
    column(2, 
         radioButtons("toggle_type", "Type", choices = c("all", "none", "choose"), selected = "choose", inline = TRUE),
         checkboxGroupInput("type",
                            "",
                            choices = types,
                            selected = types
         )   
  ),
  
  column(2,
         radioButtons("toggle_owner", "Owner", choices = c("all", "none", "choose"), selected = "choose", inline = TRUE),
         checkboxGroupInput("owner",
                            "",
                            choices = owners,
                            selected = owners 
         )
  ),
  column(2,
         radioButtons("toggle_language", "Language", choices = c("all", "none", "choose"), selected = "choose", inline = TRUE),
         checkboxGroupInput("language",
                            "",
                            choices = languages,
                            selected = languages
         )
  ),
  column(3,
         wellPanel(
           
           h4("Legend:"),
           htmlOutput("legend")
         )
  )   
  )
  )
  
  )



server <- shinyServer(function(input, output, session) {
  
  selected <- museum_data_mut %>%
    mutate(id = as.numeric(id)) %>%
    arrange(id) 

  event_data <- reactiveValues(clickedMarker = NULL)
  
  location <- reactiveValues(lat = 14.5, lon = -72)
  
  output$museum_info <- renderText({
    paste0("Number of museums: ", nrow(museum_data_mut))
    paste(c(input$type), collapse = "|")    
  })
  
  ids <- c(museum_data_mut$id)

  observeEvent({ 
    input$type
    input$owner
    input$language
  }, { 
    
    selected <- museum_data_mut %>%
      mutate(id = as.numeric(id)) %>%
      arrange(id) %>%
      filter(grepl(paste(c(input$owner, "KOMTNOOITVOOR"), collapse = "|"), owner_course), grepl(".*", owner_course)) %>%
      filter(grepl(paste(c(input$type, "KOMTNOOITVOOR"), collapse = "|"), type), grepl(".*", type)) %>%
      filter(grepl(paste0(".*(", paste(c(input$language, "KOMTNOOITVOOR"), collapse = "|"), ").*"), Languages))

    output$museum_info <- renderText({
      paste0("Number of museums selected: <strong>", nrow(selected), "</strong><br/>&nbsp;<br/>&nbsp;<br/>&nbsp;<br/>&nbsp;<br/>&nbsp;<br/>&nbsp;<br/>&nbsp;<br/>&nbsp;<br/>&nbsp;<br/>&nbsp;<br/>&nbsp;<br/>&nbsp;<br/>&nbsp;<br/>&nbsp;<br/>&nbsp;<br/>")
    })   
    
  } )
  
  
  observe({
    if (input$toggle_type == "choose") {
      shinyjs::enable("type")
    } 
    
    else if (input$toggle_type == "all") {
      updateCheckboxGroupInput(session,"type", selected=types)
      shinyjs::disable("type")
    }
    
    else  {
      updateCheckboxGroupInput(session,"type", selected="")
      shinyjs::disable("language")
    }
  })

  observe({
    if (input$toggle_owner == "choose") {
      shinyjs::enable("owner")
    } 
    
    else if (input$toggle_owner == "all") {
      updateCheckboxGroupInput(session,"owner", selected=owners)
      shinyjs::disable("language")
    }
    
    else  {
      updateCheckboxGroupInput(session,"owner", selected="")
      shinyjs::disable("owner")
    }
  })

   observe({
       if (input$toggle_language == "choose") {
         shinyjs::enable("language")
       } 
       
     else if (input$toggle_language == "all") {
       updateCheckboxGroupInput(session,"language", selected=languages)
       shinyjs::disable("language")
     }
     
       else  {
         updateCheckboxGroupInput(session,"language", selected="")
         shinyjs::disable("language")
       }
    })
  
   observeEvent(input$map_marker_click, {
    
    clicked_id    <- input$map_marker_click$id
    #location$lat  <- input$map_marker_click$lat
    #location$long <- input$map_marker_click$lng

    if(!is.null(input$map_zoom)) { zoom <- input$map_zoom }

    # leafletProxy('map') %>% 
    #   setView(lng = long, lat = lat, zoom = zoom)
    # 
    #record <- museum_data_mut %>%
    #  filter(id == as.numeric(clicked_id))
    record <- museum_data_mut[as.numeric(clicked_id),]
    
    
    museum_name   = record$Museum.name
    description   = record$Content
    address       = record$Address
    country       = record$Country.or.Island
    phone         = record$Phone   
    website       = record$Website
    opening_hours = record$Opening.hours
    languages    = record$Languages
    owner         = record$owner_course
    type          = record$type
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
        'Languages: ', languages, '<br/>',
        'Type: ', type, '<br/>',
        'Ownership: ', owner, '<br/>'
      )
      
    })
  })
  
  output$map <- renderLeaflet({
 
    if(!is.null(input$map_zoom)) { zoom <- input$map_zoom }
    if(!is.null(location$lat)) { lat <- location$lat }
    if(!is.null(location$long)) { long <- location$long }
    
    
    selected <- museum_data_mut %>%
      mutate(id = as.numeric(id)) %>%
      arrange(id) %>%
      filter(grepl(paste(c(input$owner, "KOMTNOOITVOOR"), collapse = "|"), owner_course), grepl(".*", owner_course)) %>%
      filter(grepl(paste(c(input$type, "KOMTNOOITVOOR"), collapse = "|"), type), grepl(".*", type)) %>%
      filter(grepl(paste0(".*(", paste(c(input$language, "KOMTNOOITVOOR"), collapse = "|"), ").*"), Languages))
    
    leaflet(data = selected) %>%
      setView(lng = long, lat = lat, zoom = zoom) %>%
      #addTiles(group="Base map", attribution = "Map: © OpenStreetMap contributors, CC-BY-SA, data: Csilla Ariese-Vandemeulebroucke/Leiden University as part of Nexus1492, an ERC Synergy project, under the direction of prof. dr. C.L. Hofman") %>%
      # addProviderTiles(providers$Stamen.Toner, group ="Black and white") %>%
      #addProviderTiles(providers$Esri.NatGeoWorldMap, group ="Color") %>%
      #addProviderTiles(providers$Esri.WorldImagery, group ="Satellite") %>%
      addTiles(mb_map, group="Base map")  %>%
      addTiles(mb_sat, group="Satellite")  %>%
      addMarkers(
        ~longitude,
        ~latitude,
        layerId = selected$id,
        icon = ~icon_list[icon_col],
        popup = ~as.character(paste0("<img width = '120px', src= 'http://leidenarch.nl/facades/", Facade, "'/> <br/> <strong>", Museum.name, "</strong><br>" ))
      ) %>%
     addLayersControl(
      baseGroups = c("Base map", "Satellite"),
       options = layersControlOptions(collapsed = FALSE)
      )    
    
  })
  
  output$museum_info <- renderText({
    paste0("Number of museums selected: <strong>", nrow(selected), "</strong><br/>&nbsp;<br/>&nbsp;<br/>&nbsp;<br/>&nbsp;<br/>&nbsp;<br/>&nbsp;<br/>&nbsp;<br/>&nbsp;<br/>&nbsp;<br/>&nbsp;<br/>&nbsp;<br/>&nbsp;<br/>&nbsp;<br/>&nbsp;<br/>&nbsp;<br/>")
  })
  
  output$legend <- renderText({
    paste0( 
      '<br/><strong>Types:</strong><br/>',
      '<img src="http://leidenarch.nl/icons/typ_arc"/> Archaeology<br/>',  
      '<img src="http://leidenarch.nl/icons/typ_art"/> Art<br/>', 
      '<img src="http://leidenarch.nl/icons/typ_bui"/> Built heritage<br/>',  
      '<img src="http://leidenarch.nl/icons/typ_his"/> History<br/>',  
      '<img src="http://leidenarch.nl/icons/typ_mix"/> Mixed<br/>',  
      '<img src="http://leidenarch.nl/icons/typ_nat"/> Nature/science<br/>', 
      '<img src="http://leidenarch.nl/icons/typ_pop"/> Popular<br/>',  
      '<br/><strong>Ownership:</strong><br/>',
      '<img src="http://leidenarch.nl/icons/own_gov"/> Governmental<br/>',  
      '<img src="http://leidenarch.nl/icons/own_gra"/> Grassroots<br/>',  
      '<img src="http://leidenarch.nl/icons/own_mix"/> Mixed<br/>',  
      '<img src="http://leidenarch.nl/icons/own_pri"/> Private<br/>',  
      '<img src="http://leidenarch.nl/icons/own_unk"/> Unknown<br/><br/><br/>'
     )
    
  })    
  
  output$copyright <- renderText({
     "This map was produced using a dataset collected by Csilla Ariese-Vandemeulebroucke as part of <a href='http://nexus1492.eu'>Nexus1492</a>, an ERC Synergy project, under the direction of prof. dr. C.L. Hofman. Visualisation: Wouter Kool and Mereke van Garderen<br/>&nbsp;<br/>"
  })      
  
}) 
shinyApp(ui = ui, server = server)
