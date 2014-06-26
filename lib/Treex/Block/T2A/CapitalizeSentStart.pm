package Treex::Block::T2A::CapitalizeSentStart;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has 'opening_punct' => ( isa => 'Str', is => 'ro', default => '({[‚„«‹|*"\'“' );
has 'skip_dsp_nodes' => ( isa=>'Bool', is=>'ro', default=>0);

sub process_zone {
    my ( $self, $zone ) = @_;
    
    my $a_root = $zone->get_atree();
    my $opening_punct = $self->opening_punct;

    my @dsp_aroots=();
    if (!$self->skip_dsp_nodes){
        my $t_root = $zone->get_ttree();
        @dsp_aroots = grep { defined $_ } map { $_->get_lex_anode() }
            grep { $_->is_dsp_root } $t_root->get_descendants();
    }

    # Technical root should have just one child unless something (parsing) went wrong.
    # Anyway, we want to capitalize the very first word in the sentence.
    my $first_root = $a_root->get_children( { first_only => 1 } );

    foreach my $a_sent_root ( grep {defined} ( $first_root, @dsp_aroots ) ) {
        my ($first_word) =
            first { ($_->get_attr('morphcat/pos') || '') ne 'Z' and ( $_->form // $_->lemma // '' ) !~ /^[$opening_punct]+$/ }
        $a_sent_root->get_descendants( { ordered => 1, add_self => 1 } );

        # skip empty sentences and first words with no form
        next if !$first_word || !defined $first_word->form;

        # in direct speech, capitalization is allowed only after the opening quote
        my $prev_node = $first_word->get_prev_node;
        next if $prev_node and ( $prev_node->get_attr('morphcat/pos') || '' ) ne "Z"
                and ( $prev_node->form // $prev_node->lemma // '' ) !~ /^[$opening_punct]+$/;

        $first_word->set_form(ucfirst $first_word->form);

    }
    return;
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2A::CapitalizeSentStart

=head1 DESCRIPTION

Capitalize the first letter of the first (non-punctuation)
token in the sentence, and do the same for direct speech sections.

=head1 AUTHORS 

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

Martin Popel <popel@ufal.mff.cuni.cz>

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2008-2014 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
