/*
    Ported to Odin from ckdl (https://github.com/tjol/ckdl)
    Original C implementation Copyright (c) Thomas Jollans (MIT License)

    A KDL v2 document-language parser/emitter, ported from ckdl
    (https://github.com/tjol/ckdl) into Odin.

    This file is the public API surface: short aliases for the
    `Tokenizer`/`Parser`/`Emitter` typename__action procedures defined in
    tokenizer.odin, parser.odin, and emitter.odin. See CLAUDE.md for the
    architecture and the deliberate differences from upstream ckdl (v2
    only, string input only, no CLI/bindings).
*/
package kdl

///////////////////////////////////////////////////////////////////////////////
// Aliases
//

    //
    // Tokenizer
    //
        pop_token :: tokenizer__pop_token

    //
    // Parser
    //
        next_event :: parser__next_event

    //
    // Emitter
    //
        emit_node                :: emitter__emit_node
        emit_node_with_type      :: emitter__emit_node_with_type
        emit_arg                 :: emitter__emit_arg
        emit_property             :: emitter__emit_property
        start_emitting_children  :: emitter__start_emitting_children
        finish_emitting_children :: emitter__finish_emitting_children
        emit_end                 :: emitter__emit_end
        get_buffer                :: emitter__get_buffer

    //
    // init/destroy - overloaded across Tokenizer, Parser, Emitter
    //
        init :: proc {
            tokenizer__init,
            parser__init,
            emitter__init,
        }

        destroy :: proc {
            parser__destroy,
            emitter__destroy,
        }
