###############################
##       library imports     ##
###############################

library("plyr")
library("reshape2")
library("tidyverse")
library("readtext")
library("purrr")
library("janitor")
library("xlsx")
library("readxl")
library("XML")
library("stringi")
library("stringr")
library("devtools")
library("dlookr")
library("RSQLite")
library("foreign")
library("RODBC")
library("dataQualityR")
library("sp")
library("fuzzyjoin")
library("stringi")
library("rgdal")
library("docxtractr")
library("measurements")
library("tricky")
library("purrr")
library("anytime")
library("ggplot2")


###############################
##     global variables      ##
###############################

root <-  "J:/ResearchData/ARCH/Nexus1492 Data Management/DATA_SETS/Integration/"
source_directory <- paste0(root, "data/")
output_directory <- paste0(root, "output/")
reporting_directory <- paste0(output_directory, "reporting/")
metadata_directory <- paste0(root, "metadata/")

  
# mapping of site codes from the ceramics database to their corresponding names

site_mapping = c("AAE" = "Anse a l'Eau",
                 "AAG" = "Anse a la Gourde",
                 "AD" = "Anse Duquerry", 
                 "ARG" = "Argyle",
                 "ATR" = "Anse Trabaud",
                 "BOT" = "The Bottom",
                 "BRI" = "Brighton Beach",
                 "C5" = NA,
                 "C7.17" = NA,
                 "C817" = NA,
                 "CA" = "El Carril",
                 "CE" = "",
                 "CIII" = NA,
                 "CIV" = NA,
                 "CO1" = NA,
                 "CO2" = NA,
                 "COC" = "Cocoyer St. Charles",
                 "DES" = "La Désirade",
                 "DR" = NA,
                 "EC" = "El Cabo",
                 "EF" = "El Flaco",
                 "FL" = "El Flaco",
                 "ERRM" = NA,
                 "FB" = "Friars Bay",
                 "GA" = "Grande Anse",
                 "GIR" = "Giraudy",
                 "GOD" = "Godet",
                 "HE" = "Hope Estate",
                 "JU1" = NA,
                 "JU12" = NA,
                 "JU3" = NA,
                 "JU62" = NA,
                 "KR" = "Kelby's Ridge",
                 "KR1" = "Kelby's Ridge",
                 "KR2" = "Kelby's Ridge",
                 "LB1" = NA,
                 "LL" = "La Luperona",
                 "LU"  = "La Luperona",
                 "LLB" = NA,
                 "LP" =  "La Poterie",
                 "LPO" = NA,
                 "LR" = "La Ressource",
                 "LU" = NA,
                 "MC" = "Morne Cybele",
                 "MC1" = NA,
                 "MC100" = NA,
                 "MC113" = NA,
                 "MC114" = NA,
                 "MC37" = NA,
                 "MC38" = NA,
                 "MC39" = NA,
                 "MC40" = NA,
                 "MC41" = NA,
                 "MC42" = NA,
                 "MC52" = NA,
                 "MC60" = NA, 
                 "MC62" = NA,
                 "MC63" = NA,
                 "MC64" = NA,
                 "MC76" = NA,
                 "MC85" = NA,
                 "MOR" = "Morel",
                 "NAII" = NA,
                 "NAIII" = NA,
                 "PA.17" = NA,
                 "PC" = NA,
                 "PG" = NA,
                 "PH" = "Pointe Helleux",
                 "RC" = NA,
                 "RO" = NA,
                 "SB1" = "Spring Bay",
                 "SB2" = "Spring Bay",
                 "SB3" = "Spring Bay",
                 "SDP" = "Sitio de Pepe",
                 "TST" = NA,
                 "UNKNO" = NA,
                 "VR16"  = NA)

###############################
##        functions          ##
###############################

angle2dec <- function(angle) {
  
  
  angle <- as.character(angle)
  x <- do.call(rbind, strsplit(angle, split=' '))
  x <- apply(x, 1L, function(y) {
    y <- as.numeric(y)
    y[1] + y[2]/60 + y[3]/3600
  })
  return(x)
}


empty_as_na <- function(x){
  
  # converts all empty string values to NA
  
  if("character" %in% class(x)) {
    ifelse(as.character(x)!="", x, NA)
  }
}


na_as_empty <- function(x){
  
  # converts all NA values to empty strings
  
  if("character" == class(x)) {
    ifelse(is.na(x), "", x)
  } 
}


detach_package <- function(pkg, character.only = FALSE) {
  
  # remove a certain package from the workspace
  
  if(!character.only)
  {
    pkg <- deparse(substitute(pkg))
  }
  search_item <- paste("package", pkg, sep = ":")
  while(search_item %in% search())
  {
    detach(search_item, unload = TRUE, character.only = TRUE)
  }
}


rmd_source <- function(x, ...) {

  
  library(knitr)
  source(purl(x, output = tempfile()), ...)
}


distinct_not_na <- function(df, column_name){
  
  # 
  
  df_not_na <- df %>%
   dplyr::filter(!is.na(as.name(column_name)))
  
  df_na <- df %>%
    dplyr::filter(is.na(as.name(column_name))) %>%
    distinct(as.name(column_name))
  
  df_new <- bind_rows(df_na, df_not_na)
  
  return(df_new)
}
  
find_duplicates <- function(df, column_name) {
  
  # finds the number of occurrences of each value in a given column. handy for duplicates detection
  
  column <- as.name(column_name)
  
  df %>%
    group_by(column) %>%
    summarize(n())
}


normalize = function(df, site_name = "", convert_year = FALSE) {
  
  
  # function taht bundels the most frwequently occurring normalization routines, like 
  # - harmonizing column names (snake case), 
  # - converting diverse flavors of values to NA
  # - converting logical columns
  # - converting weird stuff in numeric values 
  # optionally converts the year and adds a site to the table

  new_df <- df %>%
    #mutate_all(as.character()) %>% 
    clean_names(case = "snake") %>% 
    filter_all(any_vars(!is.na(.))) %>%
    select(-starts_with("x_")) %>%
    #rename_all(.funs = funs(gsub("_$", "", .))) %>%
    #remove_empty(which = c("rows", "cols")) %>%
    na_if("NA") %>% na_if("") %>% na_if("-") %>% na_if("?")  %>% 
    na_if("??") %>% na_if("???") %>% na_if("N/A") %>%
    na_if("NULL") %>% na_if("unknown") %>%
    mutate_at(vars(contains("weight")), ~gsub(",", ".", .)) %>%
    mutate_all(function(x) gsub("^Y$","TRUE",x)) %>%
    mutate_all(function(x) gsub("^N$","FALSE",x))%>%
    mutate_all(function(x) gsub("^y$","TRUE",x)) %>%
    mutate_all(function(x) gsub("^n$","FALSE",x)) %>%
    mutate_all(function(x) gsub("^yes$","TRUE",x)) %>%
    mutate_all(function(x) gsub("^no$","FALSE",x)) %>%
    mutate_all(function(x) gsub("^YES$","TRUE",x)) %>%
    mutate_all(function(x) gsub("^NO$","FALSE",x))

    
  
  if(convert_year == TRUE) {
    
    new_df <- new_df %>% mutate(year = paste0("20", gsub("[a-zA-Z]+", "", site)))
    
  }
  
  if(site_name != ""){

    new_df <- new_df %>% mutate(site = site_name)
  }
  
  
  return(new_df)
  
}


as_integer_if_possible <- function(dat)   {
  
  # converts all convertable columns to integer 
  
  numericable <- sapply(dat, FUN=function(ii)   {
    
        integer         <- all(grepl("^[0-9]+$", ii[!is.na(ii)]))
        ret             <- rbind(integer,integer)
    return(ret)
  })
  
  changeVariables <- colnames(dat)[numericable[1,]]

  if(length(changeVariables) > 0)  {   
  
    do <- paste(mapply(function(ii) {
      paste("try(dat$'", ii , "' <- as.integer(dat$'",ii, "'), silent=TRUE)" , sep = "" )
      
      }, changeVariables), collapse = ";" )
    print(do)
    eval(parse(text = do))
  }

    return(dat)
} 


as_double_if_possible <- function(dat)   {
  
  # converts all convertable columns to double 

    numericable <- sapply(dat, FUN=function(ii)   {
    double          <- all(grepl("^[0-9]+([\\.,][0-9]+)?$", ii[!is.na(ii)]))
    ret             <- rbind(double, double)
    return(ret)
  })
  
  changeVariables <- colnames(dat)[numericable[1,]]
  
  if(length(changeVariables) > 0)   {   
    
    do <- paste(mapply(function(ii) {
      paste("try(dat$'", ii , "' <- as.double(gsub(',', '.', dat$'",ii, "')), silent=TRUE)" , sep = "" )
      
    }, changeVariables), collapse = ";" )
    
    print(do)
    eval(parse(text = do))
  }
  
  return(dat)
} 

as_double_if_any<- function(dat)   {
  
  # converts all convertable columns to double 
  
  
  numericable <- sapply(dat, FUN=function(ii)   {
    double          <- any(grepl("^[0-9]+([\\.,][0-9]+)?$", ii[!is.na(ii)]))
    ret             <- rbind(double, double)
    return(ret)
  })
  
  changeVariables <- colnames(dat)[numericable[1,]]
  
  if(length(changeVariables) > 0)   {   
    
    do <- paste(mapply(function(ii) {
      paste("try(dat$'", ii , "' <- as.double(gsub(',', '.', dat$'",ii, "')), silent=TRUE)" , sep = "" )
      
    }, changeVariables), collapse = ";" )
    
    print(do)
    eval(parse(text = do))
  }
  
  return(dat)
} 

as_logical_if_possible <- function(dat)   {
  
  # converts all convertable columns to logical 
  
  changeable <- sapply(dat, FUN=function(ii)   {
    na_original     <- sum(is.na(ii))
    logical       <- all(grepl("^(TRUE)|(FALSE)$", ii[!is.na(ii)], ignore.case = TRUE))
    ret             <- rbind(logical, logical)
    return(ret)
  })
  
  changeVariables <- colnames(dat)[changeable[1,]]
  
  if(length(changeVariables) > 0)   {   
    
    do <- paste(mapply(function(ii) {
      
      paste("try(dat$'", ii , "' <- as.logical(dat$'",ii, "'), silent=TRUE)" , sep = "" )
      
      }, changeVariables), collapse = ";" )
    
    print(do)
    eval(parse(text = do))
  }
  
  return(dat)
} 


guess_and_convert_types <- function(df){
  
  # bundle the above in the right order
  
  df %>% 
    as_double_if_possible() %>% 
    as_integer_if_possible() %>%
    as_logical_if_possible()
  
}

create_foreign_key <- function(df1, df2, by, var){
  
  # function for adding a foreign key column to a table linking to another to a table 
  # adds the id value from the second data frame to the fk of the first data frame. 
  # assumes both data frames have an id column
  # Parameters are the  columns to joined by  and the variable name to be used in the fk column name
  
  col_name <- paste0(var, "_id")
  
  df1 %>% 
    left_join(df2, by = by, na_matches = "never") %>%
    mutate(!!col_name := id.y) %>%
    select(-id.y, -matches(paste0("^", var, "$"))) %>%
    rename(id = id.x)
}

check_foreign_key <- function(df1, df2, by, var){
  
  # variant of the function above that checks if the foreign key can be created
  col_name <- paste0(var, "_id")
  
  df1 %>% 
    left_join(df2, by = by, na_matches = "never", keep = TRUE) %>%
    mutate(!!col_name := id.y) %>%
    rename(id = id.x)
}

create_finds_table <- function(df) {
  
  # bundles operations to create foreign keys for a finds table.
  
  df %>%
    mutate(id = 1:n())  %>%
    #create_foreign_key(report_linking_table, by=c("site",  "year"), "publication") %>%
    create_foreign_key(zssql_linking_table, by = c("site", "fnd"), var = "zssql") %>%
    create_foreign_key(material_linking_table, by = c("material" = "name"), var = "material") %>%
    create_foreign_key(site_linking_table, by = c("site" = "name"), var = "site") %>%
    select(-matches("^zone$"), -matches("^sector$"), -matches("^square$"), -matches("^layer$"), -matches("^feature$"), -matches("^level$"), -matches("^fill$"), -matches("^unit$"), -matches("^date$"), -matches("^year$"), -matches("^site$"), -matches("^fnd$"), -matches("^type$") ) %>% 
    distinct(id, .keep_all = TRUE)
  
}


create_value_list <- function(df, name_column, id_column) {
  
    # creates a value_list based on a given column. 

    df %>% 
      distinct_(name_column, id_column) %>% 
      rename_(name = name_column, id = id_column) %>%
      #filter(!is.na(name)) %>%
      mutate(name = as.factor(name)) 
}



write_output <- function(tables) {
  
  # writes output a s an mysql insert query
  
  output_file  = paste0(output_directory, "nexus1492_project_",  Sys.Date(), ".sql")

  start <- paste0(    
    "-- NEXUS1492 Project database version ", Sys.Date(), ";\n",
    "DROP DATABASE IF EXISTS nexus1492_project;\n\n",
    "CREATE DATABASE nexus1492_project;\n\n",
    "USE nexus1492_project;\n\n",
    "CREATE TABLE metadata_database(version_date VARCHAR(20), to_do VARCHAR(1000));\n\n",
    "INSERT INTO metadata_database VALUES ( '", Sys.Date(), "', '", to_do, "');\n\n"
  )
  
  insert_query <- start
  
  #table_name = "bone_bulk"
  for (table_name in tables) {
    
    table = eval(parse(text = table_name)) %>% 
      mutate_all(str_replace_all, "'", "&apos;") %>% 
      mutate_all(str_replace_all, "é", replacement = "\\N{Latin Small Letter E with acute}") %>% 
      mutate_all(str_replace_all, "ê", replacement = "\\N{Latin Small Letter E with circumflex}") %>% 
      mutate_all(str_replace_all, "è", replacement = "\\N{Latin Small Letter E with grave}") %>% 
      mutate_all(str_replace_all, "á", replacement = "\\N{Latin Small Letter A with acute};") %>% 
      mutate_all(str_replace_all, "â", replacement = "\\N{Latin Small Letter A with circumflex}") %>% 
      mutate_all(str_replace_all, "à", replacement = "\\N{Latin Small Letter A with grave}") %>%
      mutate_all(str_replace_all, "±", replacement = "&plusmn;") %>%
      lapply(parse_guess) %>%
      as.data.frame()  %>%
      mutate_if(sapply(., is.factor), as.character) %>%
      mutate_each(funs(as.numeric), contains("_weight"))
 
    
    cols_types <- tibble(name = colnames(table), type = sapply(table, class)) %>%
      mutate(type = gsub("character","VARCHAR(100)", type)) %>%
      mutate(type = gsub("integer","INT(6)", type)) %>%
      mutate(type = gsub("numeric","DOUBLE", type)) %>%
      mutate(type = gsub("logical","BIT", type)) 
    
    foreign_keys <- cols_types %>%
      dplyr::filter(grepl("_id", name)) %>%
      select(name)
    
    
    table <- table %>% 
      mutate_if(is.logical, as.numeric)
    
    cols <- paste0(apply(cols_types, 1, function(x) paste0(x, collapse = " ")), collapse = ", ")
    fks <- ifelse( 
        nrow(foreign_keys) > 0,
        paste0(", ", apply(foreign_keys, 1, function(x) paste0("CONSTRAINT fk_", gsub("_id", "", x), " FOREIGN KEY (", x, ") REFERENCES ", gsub("_id", "", x), "(id)")), collapse = ""),
        ""
    )

    values <- paste0(apply(table, 1, function(x) paste0("('", paste0(x, collapse = "', '"), "')")), collapse = ",\n")
    create_table = paste0("CREATE TABLE ", table_name, " (", cols, ", \nPRIMARY KEY(id)", fks, ");\n\n")
    insert_into = paste0("INSERT INTO ", table_name, " VALUES ", gsub('(NA)+', 'NULL', values, ignore.case=F) , ";\n\n")
    insert_into <- gsub("\'NULL\'", "NULL", insert_into)
    
    insert_query <- paste0(insert_query, create_table, insert_into)
    
  }
  
  stri_write_lines(insert_query, output_file)
} 



write_excel_output <- function(tables, directory=NA) {
  
  # writes output as a series of excel files
 
  if(is.na(output_directory)) {
    
    output_file  = paste0(output_directory, "nexus1492_reporting_", Sys.Date(), ".xlsx")
  }
  
  else {
    
    output_file  = paste0(directory, "nexus1492_reporting_", Sys.Date(), ".xlsx")
    
  }
  
  n = 0
  
  for (table_name in tables) {
    
    n = n + 1
    
    table = eval(parse(text = table_name)) %>% 
      mutate_all(str_replace_all, "'", "&apos;") %>% 
      mutate_all(str_replace_all, "é", replacement = "\\N{Latin Small Letter E with acute}") %>% 
      mutate_all(str_replace_all, "ê", replacement = "\\N{Latin Small Letter E with circumflex}") %>% 
      mutate_all(str_replace_all, "è", replacement = "\\N{Latin Small Letter E with grave}") %>% 
      mutate_all(str_replace_all, "á", replacement = "\\N{Latin Small Letter A with acute};") %>% 
      mutate_all(str_replace_all, "â", replacement = "\\N{Latin Small Letter A with circumflex}") %>% 
      mutate_all(str_replace_all, "à", replacement = "\\N{Latin Small Letter A with grave}") %>%
      mutate_all(str_replace_all, "±", replacement = "&plusmn;") %>%
      mutate_all(str_replace_all, "\\n+", replacement = " ") %>%
      mutate_all(str_replace_all, "\\r+", replacement = " ") %>%
      lapply(parse_guess) %>%
      as.data.frame()  %>%
      mutate_if(sapply(., is.factor), as.character) %>%
      mutate_each(funs(as.numeric), contains("_weight"))
  
    if (n > 1) { 
      
      write.xlsx(table, output_file, sheetName = table_name, append = TRUE)
    }
    
    else {
      
      write.xlsx(table, output_file, sheetName = table_name)
      
    }
    
  }
}

write_csv_output <- function(tables) {
  
  # writes output as a series of csv files
  
  for (table_name in tables) {
    
    table = eval(parse(text = table_name)) %>% 
      mutate_all(str_replace_all, "'", "&apos;") %>% 
      mutate_all(str_replace_all, "é", replacement = "\\N{Latin Small Letter E with acute}") %>% 
      mutate_all(str_replace_all, "ê", replacement = "\\N{Latin Small Letter E with circumflex}") %>% 
      mutate_all(str_replace_all, "è", replacement = "\\N{Latin Small Letter E with grave}") %>% 
      mutate_all(str_replace_all, "á", replacement = "\\N{Latin Small Letter A with acute};") %>% 
      mutate_all(str_replace_all, "â", replacement = "\\N{Latin Small Letter A with circumflex}") %>% 
      mutate_all(str_replace_all, "à", replacement = "\\N{Latin Small Letter A with grave}") %>%
      mutate_all(str_replace_all, "±", replacement = "&plusmn;") %>%
      mutate_all(str_replace_all, "\\n+", replacement = " ") %>%
      mutate_all(str_replace_all, "\\r+", replacement = " ") %>%
      lapply(parse_guess) %>%
      as.data.frame()  %>%
      mutate_if(sapply(., is.factor), as.character) %>%
      mutate_each(funs(as.numeric), contains("_weight"))
    
    output_file  = paste0(output_directory, "nexus1492_project_", table_name, "_", Sys.Date(), ".csv")
    
    write.csv(table, output_file)
    
  }
}

write_msaccess_output <- function(tables) {
  
  # writes a msaccess insert query (does not work yet)
  
  output_file  = paste0(output_directory, "nexus1492_project_",  Sys.Date(), "_msaccess.sql")

  start <- paste0(
    "CREATE TABLE metadata_database (version_date CHAR (20), to_do CHAR (100));\r\n",
    "INSERT INTO metadata_database VALUES ( '", Sys.Date(), "', '", to_do, "');\r\n"
  )
  
  creates <- ""
  alters <- ""
  inserts <- ""
  
  for (table_name in tables) {
    
    table = eval(parse(text = table_name)) %>% 
      mutate_all(str_replace_all, "'", "&apos;") %>% 
      mutate_all(str_replace_all, "é", replacement = "\\N{Latin Small Letter E with acute}") %>% 
      mutate_all(str_replace_all, "ê", replacement = "\\N{Latin Small Letter E with circumflex}") %>% 
      mutate_all(str_replace_all, "è", replacement = "\\N{Latin Small Letter E with grave}") %>% 
      mutate_all(str_replace_all, "á", replacement = "\\N{Latin Small Letter A with acute};") %>% 
      mutate_all(str_replace_all, "â", replacement = "\\N{Latin Small Letter A with circumflex}") %>% 
      mutate_all(str_replace_all, "à", replacement = "\\N{Latin Small Letter A with grave}") %>%
      mutate_all(str_replace_all, "±", replacement = "&plusmn;") %>%
      mutate_all(str_replace_all, "\\n+", replacement = " ") %>%
      mutate_all(str_replace_all, "\\r+", replacement = " ") %>%
      lapply(parse_guess) %>%
      as.data.frame()  %>%
      mutate_if(sapply(., is.factor), as.character) %>%
      mutate_each(funs(as.numeric), contains("_weight"))
    
    cols_types <- tibble(name = colnames(table), type = sapply(table, class)) %>%
      mutate(type = gsub("character","CHAR (200)", type)) %>%
      mutate(type = gsub("integer","LONG", type)) %>%
      mutate(type = gsub("numeric","NUMBER", type)) %>%
      mutate(type = gsub("logical","BIT", type)) 

    foreign_keys <- cols_types %>%
      dplyr::filter(grepl("_id", name)) %>%
      select(name)
    
    table <- table %>% 
      mutate_if(is.logical, as.numeric)
    
    alter_table <- ifelse( 
      nrow(foreign_keys) > 0,
      paste0(apply(foreign_keys, 1, function(x) paste0("ALTER TABLE ",  table_name, " ADD CONSTRAINT fk_", gsub("_id", "", x), "_", table_name, " FOREIGN KEY (", x, ") REFERENCES ", gsub("_id", "", x), "(id);\r\n")), collapse = ""),
      ""
    )
    
    cols <- paste0(apply(cols_types, 1, function(x) paste0(x, collapse = " ")), collapse = ", ")
    values <- paste0(apply(table, 1, function(x) paste0("INSERT INTO ", table_name,  " VALUES ('", paste0(x, collapse = '\', \''), "');")), collapse = "\r\n")
    create_table = paste0("CREATE TABLE ", table_name, " (", cols, ",  CONSTRAINT pk_id_", table_name,  " PRIMARY KEY (id));\r\n")
    insert_into = paste0(gsub('NA', 'NULL', values, ignore.case=F) , "\r\n")
    insert_into <- gsub("\'NULL\'", "NULL", insert_into)
    
    creates <- paste0(creates, create_table)
    inserts <- paste0(inserts, insert_into)
    alters <- paste0(alters, alter_table)
    
  }
  
  insert_query <- paste0(start, creates, inserts, alters)
  stri_write_lines(insert_query, output_file)
} 


batch_rename <- function(df, find, replace){
  
  # batch renames column names

  df %>% rename_(.dots=setNames(names(.), tolower(gsub(find, replace, names(.)))))
}

check_completeness <- function(df) {
  
  completeness <- data.frame(column = colnames(df), completeness = apply(df, 2, function(col)round((sum((!is.na(col)))/length(col)) * 100, digits =  2)))

  return(completeness)
}


create_completeness_report <- function(tables) {
  
  # create a completeness report of a table
  
  completeness_report = tibble()
  
  for (table_name in tables) {
    
    table = eval(parse(text = table_name))
    completeness <- check_completeness(table) %>%
      mutate(table = table_name)%>%
      mutate_all(as.character)

     completeness_report <- bind_rows(completeness_report, completeness)
  }  
  return(completeness_report)
    
}


sort_points <- function(df, clockwise = TRUE) {
  
  # NA check, if NAs drop them
  if (any(is.na(c(df$latitude, df$longitude)))) {
    
    # Raise warning
    warning("Missing coordinates were detected and have been removed.", 
            call. = FALSE)
    
    return
    
  }
  
  # Get centre (-oid) point of points
  x_centre <- mean(df$latitude)
  y_centre <- mean(df$longitude)
  
  # Calculate deltas
  df$x_delta <- df$latitude - x_centre
  df$y_delta <- df$longitude - y_centre
  
  # Resolve angle, in radians
  df$angle <- atan2(df$y_delta, df$x_delta)
  # d$angle_degrees <- d$angle * 180 / pi
  
  # Arrange by angle
  if (clockwise) {
    
    df <- df[order(df$angle, decreasing = TRUE), ]
    
  } else {
    
    df <- df[order(df$angle, decreasing = FALSE), ]
    
  }
  
  # Drop intermediate variables
  df[, c("x_delta", "y_delta", "angle")] <- NULL
  
  # Return
  df
  
}

calculate_total_size <- function(table_names){
  
  result = tibble()
  total_records = 0
  total_datapoints = 0
  
  for (table_name in table_names) {
    
    table = eval(parse(text = table_name))
    number_of_records = nrow(table) 
    number_of_datapoints = nrow(table) * ncol(table)
    
    tempdf <- tibble(table = c(table_name), records = c(number_of_records), data_points =  c(number_of_datapoints))
    total_records = total_records + number_of_records
    total_datapoints = total_datapoints + number_of_datapoints
    
    
    result <- bind_rows(result, tempdf)
  }
  
  return(bind_rows(result, tibble(table = c("total"), records = c(total_records), data_points = c(total_datapoints))))
}


reinstall_packages <- function(){

    lib_path <- .libPaths()[1]
    
    ip <- as.data.frame(installed.packages(), stringsAsFactors=FALSE) 
    ip <- subset(ip, !grepl("MRO", ip$LibPath))
    ip <- ip[!(ip[,"Priority"] %in% c("base", "recommended")),]
    package_list = ip$Package
    
    sapply(package_list, detach_package)
    sapply(package_list, remove.packages, lib = lib_path)
    
    install.packages(package_list)

}

remove_na_columns <- function(dataframe){
  
  dataframe[colSums(!is.na(dataframe)) > 0]
}

fix_missing_values <- function(data){
  
  data[is.na(data)] <- NA
  data[data == '?'] <- NA
  data[data == 'NULL'] <- NA
  data[data == is.null(data)] <- NA
  data[data == 0] <- NA
  data[data == "0"] <- NA
  
  return(data)
}

non_uniques <- function(col) {
  
  n_occur <- data.frame(table(col))
  return(n_occur[n_occur$Freq > 1,])
  
}


sort_levels <- function(data){
  
  sorted_levels <- paste(sort(as.integer(levels(data))))
  data <- factor(data, levels = sorted_levels)
  
  return(data)
}


find_table_to_long_view <- function(df, weights_only = FALSE){

  df_transformed <- df %>%
    mutate_all(as.character())   %>%
    mutate_at(vars(matches("(weight)|(mni)|(number)|(nisp)|(count)")), funs(gsub("[^0-9]+", "", .))) %>%
    mutate_at(vars(matches("(weight)|(mni)|(number)|(nisp)|(count)")), as.numeric)
  
  df_weights = tibble()
  df_numbers = tibble()
  
  df_weights <- df_transformed %>%
    select(unit, contains("weight")) %>%
    select_if(colSums(!is.na(.)) > 0)  %>%
    adorn_totals(where = "col", na.rm = TRUE) %>%
    mutate(measurement = "weight") %>%
    rename(value = Total) %>%
    select(unit, measurement, value) %>%
    mutate(value = as.numeric(value)) %>%
    mutate(value = ifelse(is.na(value),0,value)) %>%
    mutate(unit = as.character(unit)) %>%
    mutate(unit = gsub("[A-Za-z ]+", "", unit)) %>%
    dplyr::filter(!is.na(unit))

  if(weights_only != TRUE){
    
    df_numbers <- df_transformed %>%
    select(unit, matches("(mni)|(nisp)|(number)")) %>%
    select_if(colSums(!is.na(.)) > 0)  %>%
    adorn_totals(where = c("col"), na.rm = TRUE) %>%
    mutate(measurement = "number") %>%
    rename(value = Total) %>%
    select(unit, measurement, value) %>%
    mutate(value = ifelse(is.na(value),0,value)) %>%
    mutate(unit = gsub("[A-Za-z ]+", "", unit)) %>%
    mutate(value = as.numeric(value)) %>%
    mutate(unit = as.character(unit)) %>%
    mutate(unit = gsub("[A-Za-z ]+", "", unit)) %>%
    dplyr::filter(!is.na(unit))

  }
    
  df_long <- bind_rows(df_weights,df_numbers)
    
  return(df_long)

}

###############################
##          reporting        ##
###############################

plot_material_per_unit <- function(data, material, output_directory, scale_num, split_no, measurement, site_var){
  
  print(reporting_directory)
  title = paste0(site_var, " ", material, " ", measurement, " per unit")
  spreadsheet_filename = paste0(output_directory, site_var, "_", material, "_", measurement, "_totals.xlsx")
  spreadsheet_filename_2 = paste0(output_directory, site_var, "_", material, "_", measurement, ".xlsx")
  
  plot_filename =  paste0(output_directory, site_var, "_", material, "_", measurement, ".png")
  svg_filename =  paste0(output_directory, site_var, "_", material, "_", measurement, ".png")
  eps_filename =  paste0(output_directory, site_var, "_", material, "_", measurement, ".png")
  pdf_filename =  paste0(output_directory, site_var, "_", material, "_", measurement, ".png")
  
  
  units <- data %>%
    select(unit) %>%
    mutate(unit = as.numeric(unit))
  
  split_at = round(max(units$unit) / split_no)
  #levels = c(paste0("units up to ",  split_at), paste0("units above ", split_at))
  
  my_measurement = measurement
  
  totals <- data  %>% 
    filter(!is.na(unit)) %>%
    filter(measurement == my_measurement) %>%
    dplyr::group_by(unit) %>% 
    mutate(value = ifelse(is.na(value),0,value)) %>%
    mutate(value =  as.numeric(value)) %>%
    dplyr::summarise(total = sum(value), na.rm = TRUE ) %>%
    mutate(unit = as.numeric(as.character(unit))) %>%
    filter(!is.na(unit)) %>%
    filter(unit >0) %>%
    mutate(group = ifelse(unit <= split_at, "1", "2")) %>%
    glimpse()
  
  totals$unit = factor(totals$unit, levels = 1:100) 
  
  scale <- case_when(
    ((measurement == "weight") & (scale_num == 1000)) ~ "(kg)",
    ((measurement == "weight") & (scale_num == 1)) ~ "(gr)",
    ((measurement == "number") & (scale_num == 1000)) ~ "(x1000)",
    ((measurement == "number") & (scale_num == 1)) ~ ""
  )
  
  
  totals %>%
    ggplot(na.rm = TRUE) + 
    geom_bar(mapping = aes(x = unit, y = total / scale_num, fill = unit), stat="identity") + 
    facet_wrap( . ~ group  , scales = "free_x", ncol = 1) +
    theme(
      strip.background = element_blank(),
      strip.text.x = element_blank()
    ) + 
    labs(title = title, x = "unit", y=paste0(site_var, " ", measurement, " ", scale)) +
    theme(legend.position="none")
  
  
  ggsave(plot_filename)
  ggsave(svg_filename)
  ggsave(pdf_filename)
  ggsave(eps_filename)
  
  write.xlsx(totals, spreadsheet_filename)
  write.xlsx(data, spreadsheet_filename_2)
  
  
}
