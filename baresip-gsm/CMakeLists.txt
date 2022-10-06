project(gsm)

set(SRCS gsm.c)

add_library(${PROJECT_NAME} OBJECT ${SRCS})

target_include_directories(${PROJECT_NAME} PRIVATE ${GSM_INCLUDE_DIR})

target_link_libraries(${PROJECT_NAME} PRIVATE ${GSM_LIBARY})
