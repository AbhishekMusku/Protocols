module apb_soc_top #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter N_SLAVES   = 4,       
	parameter NUM_MASTERS = 4,
    parameter SLAVE_ADDR_BITS = 10  // 1KB address space per slave
)(
    input  logic                    pclk,
    input  logic                    resetn,

    // External Host Interface
    input  logic [NUM_MASTERS-1:0] ext_transfer_i, // Start Transaction
    input  logic [NUM_MASTERS-1:0] ext_write_i,    // 1=Write, 0=Read
    input  logic [ADDR_WIDTH-1:0]   ext_addr_i [NUM_MASTERS-1:0],     // Address to access
    input  logic [DATA_WIDTH-1:0]   ext_data_i [NUM_MASTERS-1:0],     // Data to write
    

    output logic                    soc_ready_o,    // Corresponds to m_pready
    output logic [DATA_WIDTH-1:0]   soc_rdata_o     // Data read from slaves
);

    // Internal APB Bus Signals
    // Master <-> Interconnect
	logic [NUM_MASTERS-1:0]		prequest;
	logic [NUM_MASTERS-1:0]		pgrant;
    logic [ADDR_WIDTH-1:0]		m_paddr  [NUM_MASTERS-1:0];
    logic [DATA_WIDTH-1:0]		m_pwdata [NUM_MASTERS-1:0];
    logic [DATA_WIDTH-1:0]		m_prdata;
    logic [NUM_MASTERS-1:0]    	m_psel;
    logic [NUM_MASTERS-1:0]     m_penable;
    logic [NUM_MASTERS-1:0]		m_pwrite;
    logic                    	m_pready;

    // Interconnect <-> Slaves 
    logic [ADDR_WIDTH-1:0]  s_paddr [N_SLAVES-1:0];
    logic [DATA_WIDTH-1:0]  s_pwdata [N_SLAVES-1:0];
    logic [DATA_WIDTH-1:0]  s_prdata [N_SLAVES-1:0];
    logic [N_SLAVES-1:0]                  s_psel;
    logic [N_SLAVES-1:0]                  s_penable;
    logic [N_SLAVES-1:0]                  s_pwrite;
    logic [N_SLAVES-1:0]                  s_pready;

    //APB Master Instance
	genvar i;
	generate
		for (i = 0; i < NUM_MASTERS; i++) begin
			apb_master #(
				.ADDR_WIDTH(ADDR_WIDTH),
				.DATA_WIDTH(DATA_WIDTH)
			) u_master (
				.pclk       (pclk),
				.resetn     (resetn),
				// External Control Inputs
				.write      (ext_write_i[i]),
				.data       (ext_data_i[i]),
				.addr       (ext_addr_i[i]),
				.transfer_i (ext_transfer_i[i]),
				//Arbiter Interface
                .prequest   (prequest[i]),
                .pgrant     (pgrant[i]),
				// APB Bus Outputs
				.psel       (m_psel[i]),
				.penable    (m_penable[i]),
				.paddr      (m_paddr[i]),
				.pwrite     (m_pwrite[i]),
				.pwdata     (m_pwdata[i]),
				// APB Bus Inputs
				.pready     (m_pready),
				.prdata     (m_prdata)
			);
		end
	endgenerate	

    //Scalable Interconnect Instance
    apb_interconnect #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
		.NUM_MASTERS(NUM_MASTERS),
        .N_SLAVES(N_SLAVES),
        .SLAVE_ADDR_BITS(SLAVE_ADDR_BITS)
    ) u_interconnect (
        // Master Side
        .m_pclk     (pclk),
        .m_resetn   (resetn),
        .prequest   (prequest),
        .pgrant     (pgrant),
        .m_paddr    (m_paddr),
        .m_psel     (m_psel),
        .m_penable  (m_penable),
        .m_pwrite   (m_pwrite),
        .m_pwdata   (m_pwdata),
        .m_pready   (m_pready),
        .m_prdata   (m_prdata),

        // Slave Side (Connected via Arrays)
        .s_psel     (s_psel),
        .s_penable  (s_penable),
        .s_pwrite   (s_pwrite),
        .s_paddr    (s_paddr),
        .s_pwdata   (s_pwdata),
        .s_pready   (s_pready),
        .s_prdata   (s_prdata)
    );

    //Slave Instantiation
    generate
        for (i = 0; i < N_SLAVES; i++) begin : gen_slaves
            apb_slave_variable_latency #(
                .ADDR_WIDTH (ADDR_WIDTH),
                .DATA_WIDTH (DATA_WIDTH),
                .MEM_DEPTH  (256),
                .WAIT_CYCLES(i) 
            ) u_slave (
                .pclk       (pclk),
                .resetn     (resetn),
                .psel       (s_psel[i]),
                .penable    (s_penable[i]),
                .pwrite     (s_pwrite[i]),
                .paddr      (s_paddr[i]),
                .pwdata     (s_pwdata[i]),
                .pready     (s_pready[i]),
                .prdata     (s_prdata[i])
            );
        end
    endgenerate


    assign soc_ready_o = m_pready;
    assign soc_rdata_o = m_prdata;

endmodule