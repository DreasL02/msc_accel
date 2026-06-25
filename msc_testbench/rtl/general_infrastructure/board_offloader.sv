module board_offloader #(
    parameter int DATA_WIDTH = 8,
    parameter int DEPTH      = 8
) (
    input  logic                  clk,
    input  logic                  rst_n,

    input  logic [DATA_WIDTH-1:0] s_tdata,
    input  logic                  s_tvalid,
    output logic                  s_tready,

    output logic [DATA_WIDTH-1:0] m_axis_tdata,
    output logic                  m_axis_tvalid,
    input  logic                  m_axis_tready,
    output logic                  m_axis_tlast,


    output logic [(DEPTH <= 1) ? 1 : $clog2(DEPTH)-1:0] dbg_write_ptr,
    output logic [(DEPTH <= 1) ? 1 : $clog2(DEPTH)-1:0] dbg_read_ptr,
    output logic dbg_reading,
    output logic dbg_write_fire,
    output logic dbg_read_fire,
    output logic dbg_read_start

);

    localparam int PTR_WIDTH   = (DEPTH <= 1) ? 1 : $clog2(DEPTH);
    localparam int COUNT_WIDTH = PTR_WIDTH + 1;

    logic [DATA_WIDTH-1:0] memory [0:DEPTH-1];

    logic [PTR_WIDTH-1:0] write_ptr;
    logic [PTR_WIDTH-1:0] read_ptr;

    logic [COUNT_WIDTH-1:0] write_count;   // number stored during fill phase
    logic [COUNT_WIDTH-1:0] remain_count;  // number left to transmit during read phase

    logic reading;
    logic write_fire;
    logic read_fire;
    logic read_start;

    logic [DATA_WIDTH-1:0] out_data;
    logic                  out_valid;
    logic                  out_last;

    assign write_fire = s_tvalid && s_tready;
    assign read_fire  = out_valid && m_axis_tready;

    // Fill while not reading and not full
    assign s_tready = !reading && (write_count < DEPTH);

    // Start reading as late as possible:
    // - not already reading
    // - have at least one entry buffered
    // - either producer stopped or buffer is full
    // - sink ready right now
    assign read_start =
        !reading &&
        (write_count != 0) &&
        (!s_tvalid || (write_count == DEPTH)) &&
        m_axis_tready;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            write_ptr    <= '0;
            read_ptr     <= '0;
            write_count  <= '0;
            remain_count <= '0;
            reading      <= 1'b0;
            out_data     <= '0;
            out_valid    <= 1'b0;
            out_last     <= 1'b0;
        end else begin
            if (write_fire) begin
                memory[write_ptr] <= s_tdata;
                write_ptr         <= write_ptr + 1'b1;
                write_count       <= write_count + 1'b1;
            end

            if (read_start) begin
                reading      <= 1'b1;
                read_ptr     <= '0;
                remain_count <= write_count;
                out_data     <= memory[0];
                out_valid    <= 1'b1;
                out_last     <= (write_count == 1);
            end else if (read_fire) begin
                if (remain_count == 1) begin
                    reading      <= 1'b0;
                    write_ptr    <= '0;
                    read_ptr     <= '0;
                    write_count  <= '0;
                    remain_count <= '0;
                    out_valid    <= 1'b0;
                    out_last     <= 1'b0;
                end else begin
                    read_ptr     <= read_ptr + 1'b1;
                    remain_count <= remain_count - 1'b1;
                    out_data     <= memory[read_ptr + 1'b1];
                    out_valid    <= 1'b1;
                    out_last     <= (remain_count == 2);
                end
            end
        end
    end

    assign m_axis_tdata  = out_data;
    assign m_axis_tvalid = out_valid;
    assign m_axis_tlast  = out_last;

    assign dbg_reading = reading;
    assign dbg_write_fire = write_fire;
    assign dbg_read_fire = read_fire;
    assign dbg_read_start = read_start;
    assign dbg_write_ptr = write_ptr;
    assign dbg_read_ptr = read_ptr;
endmodule