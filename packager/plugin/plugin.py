def addressing_mode(SLAVE_DATA_WIDTH, HOST_DATA_WIDTH):
    if ((SLAVE_DATA_WIDTH == 8) and (HOST_DATA_WIDTH == 32)):
        return "byte"
    elif ((SLAVE_DATA_WIDTH == 16) and (HOST_DATA_WIDTH == 32)):
        return "lword"
    else:
        return "int"
        
def addr_range_byte(SLAVE_ADDR_WIDTH, ADDRESSING_MODE):
    if ADDRESSING_MODE == "byte":
        return (2^SLAVE_ADDR_WIDTH)*4
    elif ADDRESSING_MODE == "lword":
        return (2^SLAVE_ADDR_WIDTH)*2
    else:
        return 2^SLAVE_ADDR_WIDTH