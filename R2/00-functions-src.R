
library(rlang)
library(ggplot2)

NULL_plot <- function(n = 1, .size  = 5) {
  text <- "The series does not exhibit exuberant behavior"
  np <- list(length = n)
  for (i in 1:n) {
    np[[i]] <- ggplot() + 
      annotate("text", x = 4, y = 25, size = .size, label = text) +
      theme_void()
  }
  if (n > 1) np else np[[1]] 
}

# Custom Labels  ----------------------------------------------------------


extract_yq <- function(object) {
  yq <- object %>% 
    select_if(lubridate::is.Date) %>% 
    setNames("Date") %>% 
    mutate(Quarter = lubridate::quarter(Date),
           Year = lubridate::year(Date)) %>% 
    tidyr::unite(labels, c("Year", "Quarter"), sep = " Q") %>% 
    rename(breaks = Date)
}

custom_date <- function(object, variable, div) {
  yq <- extract_yq(object)
  seq_slice <- seq(1, NROW(yq), length.out = div)
  yq %>% 
    slice(as.integer(seq_slice)) %>% 
    pull(!!parse_expr(variable))
}

scale_custom <- function(object, div = 7) {
  require(lubridate)
  scale_x_date(
    breaks = custom_date(object, variable = "breaks", div = div),
    labels = custom_date(object, variable = "labels", div = div)
  )
}


# Plot Normal Series ------------------------------------------------------

my_theme <- theme_light() +
  theme(
    axis.title.x = element_blank(),
    panel.grid.minor = element_blank() ,
    panel.grid.major = element_line(linetype = "dashed")
  )


plot_var <- function(.data, .var, custom_labels = TRUE, rect = FALSE, 
                     rect_data = NULL, div = 7) {
  g <- .data %>% 
    # mutate(last_obs = ifelse(row_number() > nrow(.) - 1, TRUE, FALSE)) %>% 
    ggplot(aes_string("Date", as.name(.var))) +
    geom_line(size = 0.8) + 
    my_theme +
    theme(axis.title.y = element_blank())

  if (rect) {
    g <- g +  geom_rect(
      mapping = aes(xmin = Start, xmax = End, ymin = -Inf, ymax = +Inf),
      data = rect_data, inherit.aes =FALSE,
      fill = "grey70", alpha = 0.55
    )
  }
  
  if(custom_labels){
    g <- g + scale_custom(object = .data, div = div)
  }
  g
}

growth_rate <- function(x, n  = 1) (log(x) - dplyr::lag(log(x), n = n))*100

plot_growth_var <- function(.data, .var, rect_data) {
  
  .data <- .data %>% 
    mutate_at(vars(-Date), growth_rate) %>% 
    tidyr::drop_na()

  q75 <- apply(.data[,-1], 1, quantile, 0.25)
  q25 <- apply(.data[,-1], 1, quantile, 0.75)
  suppressWarnings({
    .data %>% 
      ggplot(aes_string("Date", as.name(.var))) +
      geom_rect(
        mapping = aes(xmin = Start, xmax = End, ymin = -Inf, ymax = +Inf),
        data = rect_data, inherit.aes=FALSE, fill = "grey70", alpha = 0.55)+
      geom_ribbon(aes(ymin = q25, ymax = q75), fill = "#174B97", alpha = 0.5) +
      geom_line(size = 0.8) + 
      ylab("% Quarter on Quarter") +
      my_theme +
      scale_custom(object = .data)
  })
}

# .data <- price
# .var <- "Aggregate"
# rect_data = exuber::datestamp(radf_price, mc_con)[["Aggregate"]]
    
# my_gg <- price %>% 
#   mutate(last_obs = ifelse(row_number() > nrow(.) - 1, TRUE, FALSE)) %>% 
#   mutate_if(is.numeric, round, 2) %>% 
#   ggplot(aes(Date, Australia)) +
#   geom_line() + ylab("") + xlab("") +
#   # geom_point_interactive(aes(tooltip = Australia  ,col = last_obs)) +
#   scale_color_manual(values = c("black", "red")) +
#   theme_light() + ggtitle("")
  
# library(ggiraph)
# g <- girafe(code = print(my_gg))

# Autoplot radf objects ---------------------------------------------------


analysis_theme <- theme_light() +
  theme(
    title = element_blank(),
    axis.title = element_blank(),
    panel.grid.minor = element_blank() ,
    panel.grid.major = element_line(linetype = "dashed")
  )

autoplot_var <- function(radf_var, cv_var, input, custom_labels = TRUE) {
  g <- exuber::autoplot(radf_var, cv = cv_var, include = TRUE, select = input) + 
    analysis_theme
  
  g$layers[[1]]$aes_params$size <- 0.8
  
  if(custom_labels){
    g <- g + scale_custom(object = fortify(radf_var, cv = cv_var))
  }
  g
    
}

# Datestamp into yq
to_yq <- function(ds, radf_var, cv_var){
  idx <- tibble(Date = index(radf_var, trunc = FALSE))
  index_yq <- extract_yq(idx)
  
  ds_yq <- function(ds) {
    start <- ds[, 1]
    start_ind <- which(index_yq$breaks %in% start)
    start_label <- index_yq[start_ind ,2]
    
    end <- ds[, 2]
    end_ind <- which(index_yq$breaks %in% end)
    if (anyNA(end)) end_ind <- c(end_ind, NA)
    end_label <- index_yq[end_ind ,2]
    
    ds[, 1] <- start_label 
    ds[, 2] <- end_label
    ds
  }
  
  ds %>% 
    ds_yq()
}



# download html -----------------------------------------------------------

DT_preview <- function(x, title = NULL) {
  box2(width = 12, title = title, dataTableOutput(x))
}

tab_panel <- function(x, title, prefix = "") {
  tabPanel(title, icon = icon("angle-double-right"), 
           DT_preview(x, title = paste0(prefix, title)))
}

# datatable ---------------------------------------------------------------

specify_buttons <- function(filename) {
  list(
    list(
      extend = "collection",
      buttons =
        list(
          list(extend = 'csv',
               filename = filename
               , exportOptions  =
                 list(
                   modifier = 
                     list(
                       page = "all",
                       search = 'none')
                 )
          ),
          list(extend = 'excel',
               filename = filename,
               title = "International Housing Observatory")
        ),
      text = "Download"
    )
  )
}
  
DT_summary <- function(x) {
  DT::datatable(
    x,
    rownames = FALSE,
    options = list( 
      dom = "t",
      searching = FALSE,
      ordering = FALSE
    )
  ) %>% 
    DT::formatRound(2:NCOL(x), 3) 
}

make_DT <- function(x, filename, caption_string = ""){
  DT::datatable(
    x,
    rownames = FALSE,
    caption = caption_string,
    extensions = 'Buttons',
    options = list( 
      dom = 'Bfrtip', #'Blfrtip'
      searching = FALSE,
      autoWidth = TRUE,
      paging = TRUE,
      # scrollY = T,
      scrollX = T,
      columnDefs = list(
        list(
          targets = c(0, 14, 18, 21), width = "80px")),
      buttons = specify_buttons(filename)
    )
  ) %>%
    DT::formatRound(2:NCOL(x), 3) 
}


make_DT_general <- function(x, filename) {
  DT::datatable(x,
                rownames = FALSE,
                extensions = 'Buttons',
                options = list(dom = 'Bfrtip',#'Blfrtip',
                               searching = FALSE,
                               autoWidth = TRUE,
                               paging = TRUE,
                               scrollX = F,
                               # columnDefs = list(list(targets = c(0), width = "80px")),
                               buttons = specify_buttons(filename)
                )
  ) %>%
    DT::formatRound(2:NCOL(x), 3) 
}


# html --------------------------------------------------------------------

box2 <- function(..., title = NULL, subtitle = NULL, footer = NULL, status = NULL, 
                 solidHeader = FALSE, background = NULL, width = 6, height = NULL, 
                 popover = FALSE, popover_title = NULL, popover_content = NULL,
                 data_toggle = "popover", collapsible = FALSE, collapsed = FALSE) 
{
  boxClass <- "box"
  if (solidHeader || !is.null(background)) {
    boxClass <- paste(boxClass, "box-solid")
  }
  if (!is.null(status)) {
    shinydashboard:::validateStatus(status)
    boxClass <- paste0(boxClass, " box-", status)
  }
  if (collapsible && collapsed) {
    boxClass <- paste(boxClass, "collapsed-box")
  }
  if (!is.null(background)) {
    shinydashboard:::validateColor(background)
    boxClass <- paste0(boxClass, " bg-", background)
  }
  style <- NULL
  if (!is.null(height)) {
    style <- paste0("height: ", validateCssUnit(height))
  }
  titleTag <- NULL
  if (!is.null(title)) {
    titleTag <- h3(class = "box-title", title)
  }
  subtitleTag <- NULL
  if (!is.null(title)) {
    subtitleTag <- h5(class = "box-subtitle", subtitle)
  }
  collapseTag <- NULL
  if (collapsible) {
    buttonStatus <- status %OR% "default"
    collapseIcon <- if (collapsed) 
      "plus"
    else "minus"
    collapseTag <- div(class = "box-tools pull-right", 
                       tags$button(class = paste0("btn btn-box-tool"), 
                                   `data-widget` = "collapse", shiny::icon(collapseIcon)))
  }
  popoverTag <- NULL
  if (popover) {
    popoverTag <- div(
      class = "box-tools pull-right", 
      tags$button(
        class = paste0("btn btn-box-tool"), 
        `title` = popover_title,
        `data-content` = popover_content,
        `data-trigger` = "focus",
        `data-placement` = "right",
        # `data-html` = "true",
        `data-toggle` = data_toggle, shiny::icon("info"))
    )
  }
  headerTag <- NULL
  if (!is.null(titleTag) || !is.null(collapseTag) || !is.null(popoverTag)) {
    headerTag <- div(class = "box-header", titleTag, subtitleTag, collapseTag, popoverTag)
  }
  div(class = if (!is.null(width)) 
    paste0("col-sm-", width), div(class = boxClass, style = if (!is.null(style)) 
      style, headerTag, div(class = "box-body", ...), if (!is.null(footer)) 
        div(class = "box-footer", footer)))
}

note_exuber <- 
  HTML('<span>There is exuberance when the </span> <span class="textbf"> solid line </span> <span> surpasses the </span><span class="color-red"> dashed line </span>.')

note_ds <- 
  HTML('Periods of time identified as exuberant by the financial stability analysis.')

note_shade <- 
  HTML('<span class="color-grey">Shaded areas</span> <span>indicate identified periods of exuberance.</span>')

note_bands <- 
  HTML('<span>The </span> <span class="color-grey">shaded bands </span><span> refer to the difference between the top and bottom decile of growth rates across all regions in the UK.</span>')


column_4 <- function(...) {
  column(width = 4, ...)
}