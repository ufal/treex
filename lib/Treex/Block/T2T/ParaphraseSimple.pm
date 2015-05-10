package Treex::Block::T2T::ParaphraseSimple;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';
use autodie;

has mt_selector => (
    is => 'rw',
    isa => 'Str',
    required => 1,
    documentation => 'selector of the zone with MT-output (machine translations)'
);

has paraphrases_file => (
    is => 'ro',
    isa => 'Str',
    required => 1,
    documentation => 'filename of a file with tab-separated single-lemma paraphrases, one pair of lemmas per line',
);

has paraphrases => (
    is => 'rw',
    isa => 'HashRef',
    documentation => 'Internal storage of paraphrases'
);

has mt_language => ( is  => 'rw', isa => 'Str', lazy_build => 1 );

my %seen_in_mt;
my %seen_only_in_mt;

sub _build_mt_language {
    my ($self) = @_;
    return $self->language;
}

sub process_start {
    my ($self) = @_;

    # TODO: support multiword paraphrase and formeme paraphrases
    # TODO: support paraphrases applicable only in a given (tree) context
    open my $F, '<:utf8', $self->paraphrases_file;
    my %para;
    while (<$F>){
        chomp;
        next unless $_;
        my ($lemma1, $lemma2) = split /\t/;
        $para{$lemma1}->{$lemma2} = 1;
        $para{$lemma2}->{$lemma1} = 1; # suppose symmetry
    }
    close $F;
    $self->set_paraphrases(\%para);
}

sub process_bundle {
    my ($self, $bundle, $bundleNo) = @_;
    
    # What t-lemmas are seen in this sentence in the MT-output?
    %seen_in_mt = ();
    {
        my $mt_zone = $bundle->get_zone(
            $self->mt_language, $self->mt_selector);
        my $mt_ttree = $mt_zone->get_ttree();
        my @mt_tnodes = $mt_ttree->get_descendants();
        for my $mt_tnode (@mt_tnodes) {
            $seen_in_mt{$mt_tnode->t_lemma}++;
        }
    }
    
    # What t-lemmas are seen in this sentence ONLY in the MT-output?
    %seen_only_in_mt = %seen_in_mt;
    {
        my $ref_zone = $bundle->get_zone(
            $self->language, $self->selector);
        my $ref_ttree = $ref_zone->get_ttree();
        my @ref_tnodes = $ref_ttree->get_descendants();
        for my $ref_tnode (@ref_tnodes) {
            if ( defined $seen_only_in_mt{$ref_tnode->t_lemma} ) {
                delete $seen_only_in_mt{$ref_tnode->t_lemma};
            }
        }
    }

    # Let Treex::Core::Block call process_tnode on each t-node of the reference zone
    $self->SUPER::process_bundle($bundle, $bundleNo);
    return;
}

sub process_tnode {
    my ( $self, $tnode ) = @_;
    my $orig_lemma = $tnode->t_lemma();

    if ( !$seen_in_mt{$orig_lemma} ) {
        # let's try to paraphrase
        foreach my $mt_lemma (keys %seen_only_in_mt) {
            if ( $self->paraphrases->{$orig_lemma}->{$mt_lemma} ) {
                $tnode->set_t_lemma($mt_lemma);
                # nouns may have different gender
                my $lex_anode = $tnode->get_lex_anode;
                if ( defined $lex_anode && $lex_anode->tag  =~ /^N/) {
                    $tnode->set_gram_gender(undef);
                }
                $tnode->wild->{orig_lemma} = $orig_lemma;
                $tnode->wild->{changed} = 1;
                log_info "Paraphrasing $orig_lemma -> $mt_lemma";
                last;
            }
        }
    }

    return;
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::T2T::ParaphraseSimple - change lemmas in references to resemble MT-output

=head1 USAGE

 T2T::ParaphraseSimple paraphrases_file='my/file.tsv' mt_selector=tectomt selector=reference language=cs

=head1 DESCRIPTION

Input: t-trees of reference translation and machine translation
Input: file with single-lemma paraphrases (synonyms),
in the format:
t_lemma1[tab]t_lemma2
(we assume symmetry, i.e. each entry allows paraphrasing each of the two lemmas
with the other one).
Output: modified reference translation t-tree

For each t_lemma that appears in reference but does not appear in MT,
we try to find a t_lemma that appears in the MT but not in reference
and that is an allowed paraphrase of the original t_lemma
as specified by the paraphrase file.
If we find such a t_lemma, we set it as the new t_lemma;
if the lexnode is a noun, we also undefine the gender grammateme
(to be filled later by AddNounGender block).

=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>
Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
