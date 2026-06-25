class accel_codec;

    static function void build_request_bytes(
            input  byte unsigned payload_bytes[],
            input  byte unsigned identifier,
            input  byte unsigned header,
            output byte unsigned request_bytes[]
        );
        request_bytes = new[2 + payload_bytes.size()];
        request_bytes[0] = identifier;
        request_bytes[1] = header;

        foreach (payload_bytes[i]) begin
            request_bytes[i+2] = payload_bytes[i];
        end
    endfunction


    static function bit extract_payload_bytes(
        input  byte unsigned frame_bytes[],
        output byte unsigned identifier,
        output byte unsigned header,
        output byte unsigned payload_bytes[]
    );
        if (frame_bytes.size() < 2) begin
            payload_bytes = new[0];
            identifier    = 8'h00;
            header        = 8'h00;
            return 0;
        end

        identifier = frame_bytes[0];
        header     = frame_bytes[1];

        payload_bytes = new[frame_bytes.size() - 2];
        foreach (payload_bytes[i]) begin
            payload_bytes[i] = frame_bytes[i+2];
        end

        return 1;
    endfunction
endclass
