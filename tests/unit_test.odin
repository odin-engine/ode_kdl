/*
    Ported to Odin from ckdl (https://github.com/tjol/ckdl)
    Original C implementation Copyright (c) Thomas Jollans (MIT License)

    Targeted unit tests for behavior the corpus-driven conformance test
    (conformance_test.odin) doesn't exercise: kdl_cat always parses with
    emit_comments off, so it never touches the Comment event path or the
    slashdash "commented_out" flag. Bigint overflow into the string-encoded
    Number case is also only lightly exercised by the corpus.
*/
package kdl_tests

// Core
    import "core:testing"

// ODE
    import kdl "../src"

@(test)
comment_events_are_emitted_when_enabled :: proc(t: ^testing.T) {
    doc := "// leading comment\nnode 1 /- 2\n"

    parser: kdl.Parser
    kdl.init(&parser, doc, true) // emit_comments = true
    defer kdl.destroy(&parser)

    ev := kdl.next_event(&parser)
    testing.expect_value(t, ev.type, kdl.Event_Type.Comment)
    comment_text, is_str := ev.value.variant.(string)
    testing.expect(t, is_str)
    testing.expect_value(t, comment_text, "// leading comment")

    ev = kdl.next_event(&parser)
    testing.expect_value(t, ev.type, kdl.Event_Type.Start_Node)
    testing.expect_value(t, ev.name, "node")

    ev = kdl.next_event(&parser)
    testing.expect_value(t, ev.type, kdl.Event_Type.Argument)
    n1, n1_ok := ev.value.variant.(kdl.Number)
    testing.expect(t, n1_ok)
    i1, i1_ok := n1.(i64)
    testing.expect(t, i1_ok)
    testing.expect_value(t, i1, i64(1))

    // the slashdashed argument still comes through as an event, flagged commented_out
    ev = kdl.next_event(&parser)
    testing.expect_value(t, ev.type, kdl.Event_Type.Argument)
    testing.expect(t, ev.commented_out)

    ev = kdl.next_event(&parser)
    testing.expect_value(t, ev.type, kdl.Event_Type.End_Node)

    ev = kdl.next_event(&parser)
    testing.expect_value(t, ev.type, kdl.Event_Type.EOF)
}

@(test)
integer_beyond_i64_becomes_string_encoded :: proc(t: ^testing.T) {
    doc := "node 99999999999999999999999999\n"

    parser: kdl.Parser
    kdl.init(&parser, doc)
    defer kdl.destroy(&parser)

    ev := kdl.next_event(&parser)
    testing.expect_value(t, ev.type, kdl.Event_Type.Start_Node)

    ev = kdl.next_event(&parser)
    testing.expect_value(t, ev.type, kdl.Event_Type.Argument)
    n, n_ok := ev.value.variant.(kdl.Number)
    testing.expect(t, n_ok)
    s, s_ok := n.(string)
    testing.expect(t, s_ok)
    testing.expect_value(t, s, "99999999999999999999999999")
}

@(test)
integer_within_i64_stays_an_integer :: proc(t: ^testing.T) {
    doc := "node -1234567890\n"

    parser: kdl.Parser
    kdl.init(&parser, doc)
    defer kdl.destroy(&parser)

    ev := kdl.next_event(&parser)
    testing.expect_value(t, ev.type, kdl.Event_Type.Start_Node)

    ev = kdl.next_event(&parser)
    testing.expect_value(t, ev.type, kdl.Event_Type.Argument)
    n, n_ok := ev.value.variant.(kdl.Number)
    testing.expect(t, n_ok)
    i, i_ok := n.(i64)
    testing.expect(t, i_ok)
    testing.expect_value(t, i, i64(-1234567890))
}

@(test)
empty_string_type_annotation_is_distinct_from_none :: proc(t: ^testing.T) {
    doc := "(\"\")node\n"

    parser: kdl.Parser
    kdl.init(&parser, doc)
    defer kdl.destroy(&parser)

    ev := kdl.next_event(&parser)
    testing.expect_value(t, ev.type, kdl.Event_Type.Start_Node)
    ta, has_ta := ev.value.type_annotation.?
    testing.expect(t, has_ta)
    testing.expect_value(t, ta, "")
}

@(test)
parse_error_is_reported_and_terminal :: proc(t: ^testing.T) {
    doc := "node =\n" // '=' with no preceding property name is a syntax error

    parser: kdl.Parser
    kdl.init(&parser, doc)
    defer kdl.destroy(&parser)

    ev := kdl.next_event(&parser)
    testing.expect_value(t, ev.type, kdl.Event_Type.Start_Node)

    ev = kdl.next_event(&parser)
    testing.expect_value(t, ev.type, kdl.Event_Type.Parse_Error)
    msg, msg_ok := ev.value.variant.(string)
    testing.expect(t, msg_ok)
    testing.expect(t, len(msg) > 0)
}
