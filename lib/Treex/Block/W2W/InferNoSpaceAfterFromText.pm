package Treex::Block::W2W::InferNoSpaceAfterFromText;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';



sub process_zone
{
    my $self = shift;
    my $zone = shift;
    my $root = $zone->get_atree();
    my $sentence = $zone->sentence();
    my $full_sentence = $sentence;
    my @nodes = $root->get_descendants({'ordered' => 1});
    # Ignore spaces before the sentence, if any.
    # Always assume that there is a space after the sentence.
    $sentence =~ s/^\s+//;
    $sentence .= ' ';
    foreach my $node (@nodes)
    {
        my $form = $node->form();
        $form = '' if(!defined($form));
        if(!($sentence =~ s/^\Q$form\E//))
        {
            log_warn("Full sentence: '$full_sentence'");
            log_warn("Expected form: '$form'");
            log_warn("Found this:    '$sentence'");
            log_fatal("Node form does not match the sentence string.");
        }
        if($sentence =~ s/^\s+//)
        {
            $node->set_no_space_after(undef);
        }
        else
        {
            $node->set_no_space_after(1);
        }
    }
}



1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::W2W::InferNoSpaceAfterFromText

=head1 DESCRIPTION

The C<no_space_after> attribute of nodes encodes whether the current token was
separated by a whitespace from the next token in the original sentence before
tokenization.

If this attribute is not available or is not used reliably, but we have the
correct detokenized sentence text in the sentence attribute of the zone, we
can automatically infer the token-level attributes from the text.

Prerequisite: the word forms of the nodes have not been modified from the
original.

=head1 AUTHOR

Dan Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2018 by Institute of Formal and Applied Linguistics,
Charles University in Prague

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.
