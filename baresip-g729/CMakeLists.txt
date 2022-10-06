project(g729)

set(SRCS g729.c)

add_library(${PROJECT_NAME} OBJECT ${SRCS})

target_include_directories(${PROJECT_NAME} PRIVATE ${G729_INCLUDE_DIR})
target_link_libraries(${PROJECT_NAME} PRIVATE ${G729_LIBARY})
target_compile_options(${PROJECT_NAME} PRIVATE -Wno-shorten-64-to-32)
