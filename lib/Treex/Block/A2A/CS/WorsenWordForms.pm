package Treex::Block::A2A::CS::WorsenWordForms;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Core::Block';

has 'err_distr_from' => ( is => 'rw', isa => 'Str', required => 1 );
has 'err_distr' => ( is => 'rw', isa => 'HashRef', builder => '_get_err_distr' );

my $changed = 0;
my $total = 0;

use LanguageModel::MorphoLM;
use Treex::Tool::Lexicon::Generation::CS;

my ($generator, $morphoLM);

sub process_start {
    my $self  = shift;
    $generator = Treex::Tool::Lexicon::Generation::CS->new();
    $morphoLM = LanguageModel::MorphoLM->new();

    return;
}


sub _get_err_distr {
    my ($self) = @_;
#    open (my $ERR_DISTR, "<:encoding(utf8)", $self->err_distr_from) or log_fatal $!;
    open (my $ERR_DISTR, "<:encoding(utf8)", '/a/LRC_TMP/rosa/tagchanges.tsv') or log_fatal $!;
    my %err_distr;
    while (<$ERR_DISTR>) {
        chomp;
        my ($tag_before, $tag_after, $prob) = split /\t/;
        $err_distr{$tag_before}{$tag_after} = $prob;
    }
    close($ERR_DISTR);
    return \%err_distr;
}

sub process_anode {
    my ($self, $anode) = @_;
    $total++;
    my @tags = keys %{$self->err_distr->{$anode->tag}};
    my @probs = values %{$self->err_distr->{$anode->tag}};
    my $random_value = rand();
    my $v = 0;
    foreach my $i (0 .. $#tags) {
        $v += $probs[$i];
        if ($v >= $random_value) {
            $self->regenerate_node( $anode, $tags[$i]);
            last;
        }
    }

    return;
}

sub get_form {

    my ( $self, $lemma, $tag ) = @_;

    $lemma =~ s/[-_].+$//;    # ???

    $tag =~ s/^V([ps])[IF]P/V$1TP/;
    $tag =~ s/^V([ps])[MI]S/V$1YS/;
    $tag =~ s/^V([ps])(FS|NP)/V$1QW/;

    $tag =~ s/^(P.)FS/$1\[FHQTX\-\]S/;
    $tag =~ s/^(P.)F([^S])/$1\[FHTX\-\]$2/;
    $tag =~ s/^(P.)NP/$1\[NHQXZ\-\]P/;
    $tag =~ s/^(P.)N([^P])/$1\[NHXZ\-\]$2/;

    $tag =~ s/^(P.)I/$1\[ITXYZ\-\]/;
    $tag =~ s/^(P.)M/$1\[MXYZ\-\]/;
    $tag =~ s/^(P.+)P(...........)/$1\[DPWX\-\]$2/;
    $tag =~ s/^(P.+)S(...........)/$1\[SWX\-\]$2/;

    $tag =~ s/^(P.+)(\d)(..........)/$1\[$2X\]$3/;

    my $form_info = $morphoLM->best_form_of_lemma( $lemma, $tag );
    my $form = undef;
    $form = $form_info->get_form() if $form_info;

    if ( !$form ) {
        ($form_info) = $generator->forms_of_lemma( $lemma, { tag_regex => "^$tag" } );
        $form = $form_info->get_form() if $form_info;
    }
    if ( !$form ) {
#        print STDERR "Can't find a word for lemma '$lemma' and tag '$tag'.\n";
    }
    else {
        $changed++;
    }

    return $form;
}

sub regenerate_node {
    my ( $self, $node, $new_tag ) = @_;

    $node->set_tag($new_tag);    #set even if !defined $new_form

    my $old_form = $node->form;
    my $new_form = $self->get_form( $node->lemma, $new_tag );
    return if !defined $new_form;
    $new_form = ucfirst $new_form if $old_form =~ /^(\p{isUpper})/;
    $new_form = uc $new_form      if $old_form =~ /^(\p{isUpper}*)$/;
    $node->set_form($new_form);

    return $new_form;
}

sub process_end {
    log_info "$changed wordforms (out of $total) have been changed.";

    return;
}



1;

=over

=item Treex::Block::A2A::CS::WorsenWordForms

Fixing agreement between noun and adjective.

=back

=cut

# Copyright 2011 David Marecek

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
