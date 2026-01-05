module apb_interconnect #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter N_SLAVES   = 4,          
	parameter NUM_MASTERS = 4,
    parameter SLAVE_ADDR_BITS = 10       
)(

    // Master Interface
    input  logic [NUM_MASTERS-1:0]  prequest,      // NEW
    output logic [NUM_MASTERS-1:0]  pgrant,        // NEW
	input  logic 					m_pclk,
    input  logic 					m_resetn,
    input  logic [ADDR_WIDTH-1:0]   m_paddr [NUM_MASTERS-1:0],
    input  logic [NUM_MASTERS-1:0]  m_psel,
    input  logic [NUM_MASTERS-1:0]  m_penable,
    input  logic [NUM_MASTERS-1:0]  m_pwrite,
    input  logic [DATA_WIDTH-1:0]   m_pwdata [NUM_MASTERS-1:0],
    output logic 					m_pready,
    output logic [DATA_WIDTH-1:0]   m_prdata,

    // Slave Interfaces
    // Index 0 = Slave 0, Index 1 = Slave 1, etc.
    output logic [N_SLAVES-1:0]                   s_psel,
    output logic [N_SLAVES-1:0]                   s_penable,
    output logic [N_SLAVES-1:0]                   s_pwrite,
    output logic [ADDR_WIDTH-1:0]  s_paddr [N_SLAVES-1:0],
    output logic [DATA_WIDTH-1:0]   s_pwdata [N_SLAVES-1:0],
    
    input  logic [N_SLAVES-1:0]                   s_pready,
    input  logic [DATA_WIDTH-1:0]   s_prdata [N_SLAVES-1:0]
);


    // ARBITER SIGNALS 
    logic [$clog2(NUM_MASTERS)-1:0] master_id;
    logic penable_muxed;
	

    apb_arbiter #(
        .NUM_MASTERS(NUM_MASTERS)
    ) u_arbiter (
        .pclk       (m_pclk),
        .presetn    (m_resetn),
        .prequest   (prequest),
        .pready     (m_pready),
        .penable    (penable_muxed),
        .pgrant     (pgrant),
        .master_id  (master_id)
    );
	
    // MASTER MULTIPLEXER
    logic                    psel_muxed;
    logic                    pwrite_muxed;
    logic [ADDR_WIDTH-1:0]   paddr_muxed;
    logic [DATA_WIDTH-1:0]   pwdata_muxed;

    always_comb begin
        psel_muxed    = m_psel[master_id];
        penable_muxed = m_penable[master_id];
        pwrite_muxed  = m_pwrite[master_id];
        paddr_muxed   = m_paddr[master_id];
        pwdata_muxed  = m_pwdata[master_id];
    end
    

    // Address Decoding Logic   
    localparam SEL_BITS = $clog2(N_SLAVES);
    
    logic [SEL_BITS-1:0] slave_index;

    assign slave_index = paddr_muxed[SLAVE_ADDR_BITS + SEL_BITS - 1 : SLAVE_ADDR_BITS];
	//assign slave_index = m_paddr[SLAVE_ADDR_BITS];

    //Downstream Connections (Broadcast & Select)
    
    genvar i;
    generate
        for (i = 0; i < N_SLAVES; i++) begin : gen_slaves
            assign s_paddr[i]   = paddr_muxed;
            assign s_pwdata[i]  = pwdata_muxed;
            assign s_pwrite[i]  = pwrite_muxed;
            assign s_penable[i] = penable_muxed;
            
            assign s_psel[i]    = (psel_muxed && (slave_index == i));
        end
    endgenerate


    //Upstream Connections (Multiplexing Response)
    
    always_comb begin
        m_pready = 1'b0; 
        m_prdata = '0;  

        if (psel_muxed) begin
            if (slave_index < N_SLAVES) begin
                m_pready = s_pready[slave_index];
                m_prdata = s_prdata[slave_index];
            end
        end
    end

endmodule