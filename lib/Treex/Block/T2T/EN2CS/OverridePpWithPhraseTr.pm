package Treex::Block::T2T::EN2CS::OverridePpWithPhraseTr;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

my $input_file = 'resource_data/translation_dictionaries/manually_selected_prob_Wt_given_Ws.tsv';

sub get_required_share_files { return $input_file; }

my %enphrase2csphrase;

sub BUILD {
    open my $I, "<:encoding(utf-8)", "$ENV{TMT_ROOT}/share/$input_file" or log_fatal "Can't open '$input_file' : $!";
    while (<$I>) {
        chomp;
        my ( $en_phrase, $cs_phrase ) = split /\t/;
        $enphrase2csphrase{$en_phrase} = $cs_phrase;
    }
    close($I);
}

sub process_ttree {
    my ( $self, $t_root ) = @_;

    # Process all nodes by recursion
    foreach my $child ( $t_root->get_children() ) {
        process_subtree($child);
    }
    return;
}

sub process_subtree {
    my ($cs_tnode) = @_;
    my $subtree_overriden = process_node($cs_tnode);
    if ( !$subtree_overriden ) {
        foreach my $child ( $cs_tnode->get_children() ) {
            process_subtree($child);
        }
    }
    return;
}

sub process_node {
    my ($cs_tnode) = @_;
    my $en_tnode = $cs_tnode->src_tnode or return;
    return if $en_tnode->formeme !~ /\+X/;
    return if $en_tnode->get_descendants() >= 2;
    return if $cs_tnode->get_descendants() >= 2;

    my $en_phrase = ttree2phrase($en_tnode);
    my $cs_phrase = $enphrase2csphrase{ lc($en_phrase) };
    return if !defined $cs_phrase;

    $cs_tnode->set_t_lemma($cs_phrase);
    $cs_tnode->set_formeme('phrase:');
    $cs_tnode->set_t_lemma_origin('rule-Override_pp_with_phrase_translation');
    $cs_tnode->set_formeme_origin('rule-Override_pp_with_phrase_translation');
    foreach my $descendant ( $cs_tnode->get_descendants() ) {
        $descendant->disconnect();
    }

    # Don't try to inflect this node in the synthesis
    $cs_tnode->set_nodetype('atom');    #TODO: more elegant hack

    log_debug( 'Success: ' . $cs_tnode->id . " : $cs_phrase", 1 );
    return 1;
}

sub ttree2phrase {
    my $tnode = shift;
    my @anodes =
        sort { $a->ord <=> $b->ord }
        map { $_->get_anodes } $tnode->get_descendants( { add_self => 1 } );
    return ( join ' ', grep {/[a-z]/i} map { $_->form } @anodes );
}

1;

=over

=item Treex::Block::T2T::EN2CS::OverridePpWithPhraseTr
In selected prepositional groups, the translation is overriden
with what comes from (a manually cleaned) translation dictionary
of prepositional phrases ('at all'=>'vubec' etc.)

=back

=cut

# Copyright 2008-2009 Zdenek Zabokrtsky, Martin Popel

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
