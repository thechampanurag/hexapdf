# -*- encoding: utf-8 -*-

require 'fiber'
require 'hexapdf/error'

module HexaPDF
  module PDF

    # This special Fiber class should be used when the total length of the data yielded by the fiber
    # is known beforehand. HexaPDF uses this information to avoid unnecessary memory usage.
    class FiberWithLength < Fiber

      # The total length of the data that will be yielded by this fiber. If the return value is
      # negative the total length is *not* known.
      attr_reader :length

      # Initializes the Fiber and sets the +length+.
      def initialize(length, &block)
        super(&block)
        @length = length || -1
      end

    end


    # == Overview
    #
    # A *stream filter* is used to compress a stream or to encode it in an ASCII compatible way; or
    # to reverse this process. Some filters can be used for any content, like FlateDecode, others
    # are specifically designed for image streams, like DCTDecode.
    #
    # Each filter is implemented via fibers. This allows HexaPDF to easily process either small
    # chunks or a whole stream at once, depending on the memory restrictions and to create flexible
    # filter pipelines.
    #
    # It also allows the easy re-processing of a stream without first decoding and the encoding it.
    # Such functionality is useful, for example, when a PDF file should be decrypted and streams
    # compressed in one step.
    #
    #
    # == Implementation of a Filter Object
    #
    # Each filter is an object (normally a module) that responds to two methods: #encoder and
    # #decoder. Both of these methods are given a *source* (a Fiber) and *options* (a Hash) and have
    # to return a Fiber object.
    #
    # The returned fiber should resume the *source* fiber to get the next chunk of binary data
    # (possibly only one byte of data, so this situation should be handled gracefully). Once the
    # fiber has processed this chunk, it should yield the processed chunk as binary string. This
    # should be done as long as the source fiber is #alive? and doesn't return +nil+ when resumed.
    #
    # Such a fiber should *not* return +nil+ unless this signifies that no more data is coming!
    #
    # See: PDF1.7 s7.4
    module Filter

      autoload(:ASCII85Decode, 'hexapdf/pdf/filter/ascii85_decode')
      autoload(:ASCIIHexDecode, 'hexapdf/pdf/filter/ascii_hex_decode')
      autoload(:DCTDecode, 'hexapdf/pdf/filter/dct_decode')
      autoload(:FlateDecode, 'hexapdf/pdf/filter/flate_decode')
      autoload(:JPXDecode, 'hexapdf/pdf/filter/jpx_decode')
      autoload(:LZWDecode, 'hexapdf/pdf/filter/lzw_decode')
      autoload(:RunLengthDecode, 'hexapdf/pdf/filter/run_length_decode')

      autoload(:Predictor, 'hexapdf/pdf/filter/predictor')

      autoload(:Encryption, 'hexapdf/pdf/filter/encryption')

      # Returns a Fiber that can be used as a source for decoders/encoders and that is based on a
      # String object.
      def self.source_from_string(str)
        FiberWithLength.new(str.length) { str.dup }
      end

      # Returns a Fiber that can be used as a source for decoders/encoders and that reads chunks of
      # data from an IO object.
      #
      # Each time a chunk is read, the position pointer of the IO is adjusted. This should be taken
      # into account when working with the IO object.
      #
      # Options:
      #
      # :pos:: The position from where the reading should start. A negative position is treated as
      #        zero. Default: 0.
      #
      # :length:: The length indicating the number of bytes to read. An error is raised if not all
      #           specified bytes could be read. A negative length means reading until the end of
      #           the IO stream. Default: -1.
      #
      # :chunk_size:: The size of the chunks that should be returned in each iteration. A chunk size
      #               of less than or equal to 0 means using the biggest chunk size available (can
      #               change between versions!). Default: 0.
      def self.source_from_io(io, pos: 0, length: -1, chunk_size: 0)
        orig_length = length
        chunk_size = 2**20 if chunk_size <= 0
        chunk_size = length if length >= 0 && chunk_size > length
        length = 2**61 if length < 0
        pos = 0 if pos < 0

        FiberWithLength.new(orig_length) do
          while length > 0 && (io.pos = pos) && (data = io.read(chunk_size))
            pos = io.pos
            length -= data.size
            chunk_size = length if chunk_size > length
            Fiber.yield(data)
          end
          if length > 0 && orig_length >= 0
            raise HexaPDF::Error, "Couldn't read all requested bytes before encountering EOF"
          end
        end
      end

      # Returns a Fiber that can be used as a source for decoders/encoders and that reads chunks
      # from a file.
      #
      # Note that there will be a problem if the size of the file changes between the invocation of
      # this method and the actual consumption of the file!
      #
      # See ::source_from_io for a description of the available options.
      def self.source_from_file(filename, pos: 0, length: -1, chunk_size: 0)
        fib_length = (length < 0 ? File.stat(filename).size - pos : length)
        FiberWithLength.new(fib_length) do
          File.open(filename, 'rb') do |file|
            source = source_from_io(file, pos: pos, length: length, chunk_size: chunk_size)
            while source.alive? && (io_data = source.resume)
              Fiber.yield(io_data)
            end
          end
        end
      end

      # Returns the concatenated string chunks retrieved by resuming the given source Fiber until it
      # is dead.
      #
      # The returned string is always a string with +BINARY+ (= +ASCII-8BIT+) encoding.
      def self.string_from_source(source)
        str = ''.force_encoding(Encoding::BINARY)
        while source.alive? && (data = source.resume)
          str << data
        end
        str
      end

    end

  end
end
