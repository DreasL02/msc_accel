`ifndef BOARD_DPI_PKG_INCLUDED_
`define BOARD_DPI_PKG_INCLUDED_

package board_dpi_pkg;

  // Board socket API (byte-native transport, no hardware behavior in C++)
  // Client mode helpers
  import "DPI-C" function int board_socket_connect_default();
  import "DPI-C" function int board_socket_connect(input string hostname, input int port);
  // Server mode helpers
  import "DPI-C" function int board_socket_listen(input string bind_host, input int port);
  import "DPI-C" function int board_socket_accept();
  import "DPI-C" function void board_socket_set_timeout(input int milliseconds);
  import "DPI-C" function int board_socket_send(input byte unsigned data[], input int len, output int sent);
  import "DPI-C" function int board_socket_try_recv(output byte unsigned data[], input int max_len, output int received);
  import "DPI-C" function string board_socket_get_last_payload();
  import "DPI-C" function int board_socket_try_recv_match(input string needle, input int max_len, output int received, output int matched);
  import "DPI-C" function void board_socket_close();

endpackage : board_dpi_pkg

`endif
