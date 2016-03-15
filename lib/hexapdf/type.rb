# -*- encoding: utf-8 -*-

module HexaPDF

  # == Overview
  #
  # The Type module contains implementations of the types defined in the PDF specification.
  #
  # Each type class is derived from either the Dictionary class or the Stream class, depending on
  # whether the type has an associated stream.
  module Type

    autoload(:XRefStream, 'hexapdf/type/xref_stream')
    autoload(:ObjectStream, 'hexapdf/type/object_stream')
    autoload(:Trailer, 'hexapdf/type/trailer')
    autoload(:Info, 'hexapdf/type/info')
    autoload(:Catalog, 'hexapdf/type/catalog')
    autoload(:ViewerPreferences, 'hexapdf/type/viewer_preferences')
    autoload(:PageTreeNode, 'hexapdf/type/page_tree_node')
    autoload(:Page, 'hexapdf/type/page')
    autoload(:Names, 'hexapdf/type/names')
    autoload(:FileSpecification, 'hexapdf/type/file_specification')
    autoload(:EmbeddedFile, 'hexapdf/type/embedded_file')
    autoload(:Resources, 'hexapdf/type/resources')
    autoload(:GraphicsStateParameter, 'hexapdf/type/graphics_state_parameter')
    autoload(:Image, 'hexapdf/type/image')
    autoload(:Form, 'hexapdf/type/form')

  end

end