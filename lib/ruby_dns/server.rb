require 'socket'
require 'bindata'
require 'json'

# https://tools.ietf.org/html/rfc1035
# https://tools.ietf.org/html/rfc2929
# https://tools.ietf.org/html/rfc3655
# https://www.comparitech.com/blog/vpn-privacy/udp-vs-tcp-ip/#:~:text=UDP%20stands%20for%20User%20Datagram,each%20packet%20has%20been%20received.
# https://www6.software.ibm.com/developerworks/education/l-rubysocks/l-rubysocks-a4.pdf
module RubyDns
  module QuestionType
    A = 0x0001
    NS = 0x0002
    MD = 0x0003
    MF = 0x0004
    CNAME = 0x0005
    SOA = 0x0006
    MB = 0x0007
    MG = 0x0008
    MR = 0x0009
    NULL = 0x000A
    WKS = 0x000B
    PTR = 0x000C
    HINFO = 0x000D
    MINFO = 0x000E
    MX = 0x000F
    TXT = 0x0010
  end

  module ResponseCode
    NO_ERROR = 0x0
    FORMAT_ERROR = 0x1
    SERVER_FAILURE = 0x2
    NAME_ERROR = 0x3
    NOT_IMPLEMENTED = 0x4
    REFUSED = 0x5
  end

  module ClassType
    IN = 0x01
    CS = 0x02
    CH = 0x03
    Hs = 0x04
  end

  # 12 bytes long
  class Header < BinData::Record
    endian :big

    uint16 :id, label: 'ID'
    bit1 :query_or_response, label: '0 for query, 1 for response'
    bit4 :opcode, label: '0 for query, 1 for inverse query, 2 for server status, 3-15 reserved for future use'
    bit1 :authoritative, label: '0 for non-authoritative, 1 for authoritative'
    bit1 :truncation, label: '0 for no truncation, 1 for truncation occurring'
    bit1 :recursion_desired, label: '0 for no recursion desired, 1 for recursion desired'
    bit1 :recursion_available, label: '0 for no recursion available, 1 for recursion available'
    bit1 :z, label: 'Reserved for future use'
    bit1 :authenticated_data, label: 'authenticated data'
    bit1 :non_authenticated_data, label: 'non authenticated data acceptable'
    bit4 :response_code, label: 'Response code'

    uint16 :question_count, label: 'Number of questions in the question section'
    uint16 :answer_count, label: 'Number of answers in the answer section'
    uint16 :name_server_count, label: 'Number of name server resource records in the authority records section'
    uint16 :additional_record_count, label: 'Number of resource records in the additional records sections'
  end

  class Question < BinData::Record
    endian :big

    # A domain name is represented as a sequence of labels, where
    # each label consists of a length octet followed by that number of octets
    # The domain name ends with a zero length octet. Treating as null terminated for now.
    stringz :string_data

    uint16 :question_type
    uint16 :question_class

    def domain
      result = ""
      index = 0

      while index < string_data.length
        if index > 0
          result += '.'
        end
        length = string_data[index].ord
        result += string_data[index + 1..index + length]
        index += length + 1
      end

      result + "."
    end
  end

  class ResourceRecord < BinData::Record
    endian :big

    stringz :string_data

    uint16 :question_type
    uint16 :question_class
    uint32 :ttl

    uint16 :rdlength, label: 'The length of rdata in bytes'
    uint32 :rdata
  end

  class Request < BinData::Record
    endian :big

    header :header
    array :questions, type: :question, initial_length: proc { header.question_count }
  end

  class Response < BinData::Record
    endian :big

    header :header
    array :questions, type: :question
    array :records, type: :resource_record
  end

  class Server
    attr_reader :port
    attr_reader :host

    def initialize(port: , host:, zone_paths: nil)
      @port = port
      @host = host
      @zone_paths = zone_paths || Dir["./data/zones/*.json"]
    end

    def serve
      socket = UDPSocket.new
      socket.bind(host, port)

      loop do
        data, from = socket.recvfrom(512)

        request = Request.read(data)
        records = resource_records_for(request.questions)
        response = Response.new(
          header: Header.new(
            id: request.header.id,
            query_or_response: 1,
            opcode: request.header.opcode,
            authoritative: 1,
            truncation: 0,
            recursion_desired: 0,
            recursion_available: 0,
            z: 0,
            response_code: (
              has_domain?(request.questions[0].domain) ? ResponseCode::NO_ERROR : ResponseCode::NAME_ERROR
            ),
            question_count: request.header.question_count,
            answer_count: records.count,
            name_server_count: 0,
            additional_record_count: 0
          ),
          questions: request.questions,
          records: records
        )

        socket.send(response.to_binary_s, 0, from[3], from[1])
      end
    end

    private

    attr_reader :zone_paths

    def available_zones
      @available_zones ||= load_zones
    end

    def load_zones
      zone_paths.each_with_object({}) do |zone_path, acc|
        json = JSON.parse(File.read(zone_path))
        origin = json['$origin']
        acc[origin] = json
      end
    end

    def resource_records_for(questions)
      questions.flat_map do |question|
        return [] unless has_domain?(question.domain)

        results = lookup(available_zones, question)

        results.map do |record|
          ResourceRecord.new(
            string_data: question.string_data,
            question_type: question.question_type,
            question_class: question.question_class,
            ttl: record['ttl'],
            rdlength: 4,
            rdata: IPAddr.new(record['value']).to_i
          )
        end
      end
    end

    def has_domain?(domain)
      available_zones.key?(domain)
    end

    def lookup(available_zones, question)
      domain = question.domain
      zone = available_zones[domain]

      if question.question_type == QuestionType::A
        zone['a']
      else
        []
      end
    end
  end
end
