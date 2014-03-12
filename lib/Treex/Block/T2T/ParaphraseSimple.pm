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
    documentation => 'filename of a file with space-separated single-lemma paraphrases, one pair of lemmas per line',
);

has paraphrases => (
    is => 'rw',
    isa => 'HashRef',
    documentation => 'Internal storage of paraphrases'
);

has mt_language => ( is  => 'rw', isa => 'Str', lazy_build => 1 );

my %seen_in_mt;

sub _build_mt_language {
    my ($self) = @_;
    return $self->language;
}

sub process_start {
    my ($self) = @_;


    # Only one paraphrase for each lemma is supported now.
    # TODO: support $para{$lemma} = [$para1, $para2, $para3]
    # TODO: support multiword paraphrase and formeme paraphrases
    # TODO: support paraphrases applicable only in a given (tree) context
    open my $F, '<:utf8', $self->paraphrases_file;
    my %para;
    while (<$F>){
        chomp;
        my ($lemma1, $lemma2) = split;
        $para{$lemma1} = $lemma2;
        $para{$lemma2} = $lemma1; # suppose symmetry
    }
    close $F;
    $self->set_paraphrases(\%para);
}

sub process_bundle {
    my ($self, $bundle, $bundleNo) = @_;
    
    # What t-lemmas are seen in this sentence in the MT-output?
    %seen_in_mt = ();
    my $mt_zone = $bundle->get_zone($self->mt_language, $self->mt_selector);
    my $mt_ttree = $mt_zone->get_ttree();
    my @mt_tnodes = $mt_ttree->get_descendants();
    for my $mt_tnode (@mt_tnodes) {
        $seen_in_mt{$mt_tnode->t_lemma}++;
    }
    
    # Let Treex::Core::Block call process_tnode on each t-node of the reference zone
    $self->SUPER::process_bundle($bundle, $bundleNo);
    return;
}

sub process_tnode {
    my ( $self, $tnode ) = @_;
    my $orig_lemma = $tnode->t_lemma();
    my $para_lemma = $self->paraphrases->{$orig_lemma};

    # debug print
    #say(($seen_in_mt{$para_lemma} ?  'will' : 'will not') .  " apply: $orig_lemma -> $para_lemma " . $tnode->id) if defined $para_lemma;
    if (defined $para_lemma && $seen_in_mt{$para_lemma}){
        $tnode->set_t_lemma($para_lemma);
        $tnode->wild->{orig_lemma} = $orig_lemma;
    }
    return;
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::T2T::ParaphraseSimple - change lemmas in references to resemble MT-output

=head1 USAGE

 T2T::ParaphraseSimple paraphrases_file='my/file.txt' mt_selector=tectomt selector=reference language=cs

=head1 DESCRIPTION

Input: t-trees of reference translation and machine translation
Input: file with single-lemma paraphrases (synonyms)
Output: modified reference translation t-tree

=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
