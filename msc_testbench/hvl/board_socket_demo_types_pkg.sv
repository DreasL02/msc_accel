`ifndef BOARD_SOCKET_DEMO_TYPES_PKG_INCLUDED_
`define BOARD_SOCKET_DEMO_TYPES_PKG_INCLUDED_

package board_socket_demo_types_pkg;

  // Canonical APB widths for all board-socket-demo types.
  localparam int APB_ADDR_WIDTH = 32;
  localparam int APB_DATA_WIDTH = 32;
  localparam int INCOMING_ID_WIDTH = 8;
  localparam int OUTGOING_ID_WIDTH = 8;
  localparam int INCOMING_HEADER_WIDTH = 8; // for rsp bit

  typedef struct packed {
    logic [INCOMING_HEADER_WIDTH-1:0] header;
    logic [APB_ADDR_WIDTH-1:0] m_addr;
    logic [31:0]               m_direction;
    logic [APB_DATA_WIDTH-1:0] m_data;
    logic [31:0]               m_transmit_delay;
    logic [31:0]               m_response_delay;
    logic [7:0]                m_error;
  } apb_incoming_item_t;

  localparam int INCOMING_APB_ITEM_WIDTH = $bits(apb_incoming_item_t);
  localparam int INCOMING_REQ_BASE_WIDTH = INCOMING_APB_ITEM_WIDTH + INCOMING_ID_WIDTH;

  typedef struct packed {
    logic [INCOMING_ID_WIDTH-1:0] id;
    apb_incoming_item_t           incoming_apb_item;
  } incoming_req_t;

  localparam int INCOMING_REQ_WIDTH = INCOMING_REQ_BASE_WIDTH;
  localparam int INCOMING_REQ_BYTES = (INCOMING_REQ_WIDTH + 7) / 8;

  localparam int OUTGOING_HEADER_WIDTH = 8;

  typedef struct packed {
    logic [OUTGOING_HEADER_WIDTH-1:0] header;
    logic [APB_ADDR_WIDTH-1:0]        m_addr;
    logic [31:0]                      m_direction;
    logic [APB_DATA_WIDTH-1:0]        m_data;
    logic [31:0]                      m_transmit_delay;
    logic [31:0]                      m_response_delay;
    logic [7:0]                       m_error;
  } apb_outgoing_item_t;

  localparam int OUTGOING_APB_ITEM_WIDTH = $bits(apb_outgoing_item_t);
  localparam int OUTGOING_RSP_BASE_WIDTH = OUTGOING_APB_ITEM_WIDTH + OUTGOING_ID_WIDTH;

  typedef struct packed {
    logic [OUTGOING_ID_WIDTH-1:0] id;
    apb_outgoing_item_t           outgoing_apb_item;
  } outgoing_rsp_t;

  localparam int OUTGOING_RSP_WIDTH = OUTGOING_RSP_BASE_WIDTH;
  localparam int OUTGOING_RSP_BYTES = (OUTGOING_RSP_WIDTH + 7) / 8;

  //----------------------------------------------------------------------------
  // String conversion helpers
  //----------------------------------------------------------------------------

  function automatic string apb_direction_to_string(bit dir);
    return dir ? "WRITE" : "READ";
  endfunction


  function automatic string sprint_apb_incoming_item(apb_incoming_item_t item);
    return $sformatf(
      "{header:0x%0h, addr:0x%0h, dir:%s, data:0x%0h, tx_delay:%0d, rsp_delay:%0d, error:%0b}",
      item.header,
      item.m_addr,
      apb_direction_to_string(item.m_direction),
      item.m_data,
      item.m_transmit_delay,
      item.m_response_delay,
      item.m_error
    );
  endfunction


  function automatic string sprint_incoming_req(incoming_req_t req);
    return $sformatf(
      "{id:0x%0h, incoming_apb_item:%s}",
      req.id,
      sprint_apb_incoming_item(req.incoming_apb_item)
    );
  endfunction


  function automatic string sprint_apb_outgoing_item(apb_outgoing_item_t item);
    return $sformatf(
      "{header:0x%0h, addr:0x%0h, dir:%s, data:0x%0h, tx_delay:%0d, rsp_delay:%0d, error:%0b}",
      item.header,
      item.m_addr,
      apb_direction_to_string(item.m_direction),
      item.m_data,
      item.m_transmit_delay,
      item.m_response_delay,
      item.m_error
    );
  endfunction


  function automatic string sprint_outgoing_rsp(outgoing_rsp_t rsp);
    return $sformatf(
      "{id:0x%0h, outgoing_apb_item:%s}",
      rsp.id,
      sprint_apb_outgoing_item(rsp.outgoing_apb_item)
    );
  endfunction


  //----------------------------------------------------------------------------
  // Direct print tasks
  //----------------------------------------------------------------------------

  task automatic print_apb_incoming_item(apb_incoming_item_t item, string prefix="");
    $display("%s%s", prefix, sprint_apb_incoming_item(item));
  endtask

  task automatic print_incoming_req(incoming_req_t req, string prefix="");
    $display("%s%s", prefix, sprint_incoming_req(req));
  endtask

  task automatic print_apb_outgoing_item(apb_outgoing_item_t item, string prefix="");
    $display("%s%s", prefix, sprint_apb_outgoing_item(item));
  endtask

  task automatic print_outgoing_rsp(outgoing_rsp_t rsp, string prefix="");
    $display("%s%s", prefix, sprint_outgoing_rsp(rsp));
  endtask

endpackage : board_socket_demo_types_pkg

`endif