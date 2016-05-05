package Treex::Scen::EN_Moses_preprocess;
use Moose;
use Treex::Core::Common;
with 'Treex::Core::RememberArgs';

has domain => (
     is => 'ro',
     isa => enum( [qw(general IT)] ),
     default => 'IT',
     documentation => 'domain of the input texts',
);

has resegment => (
     is => 'ro',
     isa => 'Bool',
     default => 1,
     documentation => 'Use W2A::ResegmentSentences',
);

has tag => (
     is => 'ro',
     isa => 'Bool',
     default => '0',
     documentation => 'Tag (and lemmatize) the data, output in form|lemma|tag format; otherwise output plaintext',
);

has tagger => (
     is => 'ro',
     isa => enum( [qw(Morce MorphoDiTa)] ),
     default => 'MorphoDiTa',
     documentation => 'Which PoS tagger to use',
);

has tagger_lemmatize => (
     is => 'ro',
     isa => 'Bool',
     default => '1',
     documentation => 'Use lemmatization from the tagger instead of W2A::EN::Lemmatize',
);

has fix_tags => (
     is => 'ro',
     isa => 'Bool',
     default => '1',
     documentation => 'Postprocess the tags from the tagger by FixTags, FixTagsImperative and QtHackTags',
);

has hideIT => (
     is => 'ro',
     isa => 'Bool',
     default => '1',
     documentation => 'Use W2A::HideIT and A2W::ShowIT',
);

has gazetteer => (
     is => 'ro',
     isa => 'Str',
     default => 'all',
     documentation => 'Use W2A::EN::GazeteerMatch A2T::ProjectGazeteerInfo',
);

has moses_xml => ( is => 'rw', isa => 'Bool', default => 0 );

has tokenize_moses => ( is => 'rw', isa => 'Bool', default => 0 );

has lowercase => ( is => 'rw', isa => 'Bool', default => 0 );

has truecase_moses => ( is => 'rw', isa => 'Bool', default => 0 );

has trg_lang => (
    is => 'ro',
    isa => 'Str',
    documentation => 'Gazetteers are defined for language pairs. Both source and target languages must be specified.',
    required => '1',
);

has pretokenized => (
    is => 'ro',
    isa => 'Bool',
    default => '0',
    documentation => 'Is the input pretokenized? If set to 1, will only tokenize on whitespace.'
);

has detokenize => (
    is => 'ro',
    isa => 'Bool',
    default => '1',
    documentation => 'Detokenize the output (instead of leaving tokens space-separated)'
);

has replacements_file => (
    is => 'ro',
    isa => 'Str',
    documentation => 'Filename for storing the replacements',
    default => 'replacements.dump',
);

has gazeteer_translations_file => (
    is => 'ro',
    isa => 'Str',
    documentation => 'Filename for storing the replacements',
    default => 'gazeteer_translations.dump',
);

has bundle_ids_file => (
    is => 'ro',
    isa => 'Str',
    documentation => 'Filename for storing the bundle ids',
    default => 'bundle_ids.txt',
);

sub get_scenario_string {
    my ($self) = @_;

    my $scen = join "\n",
    'Util::SetGlobal language=en selector=src',
    'Read::Sentences',
    $self->resegment ? 'W2A::ResegmentSentences' : (),
    $self->resegment ? 'Write::BundleIds to=' . $self->bundle_ids_file : (),
    $self->hideIT ? 'W2A::HideIT use_alphabetic_indexes=1' : (),
    $self->hideIT && !$self->moses_xml ? 'Write::BundleWildAttributeDump attribute=entities  to=' . $self->replacements_file : (),
    $self->pretokenized ? 'W2A::TokenizeOnWhitespace' : ($self->tokenize_moses ? 'W2A::TokenizeMoses no_escape=1 protected_patterns_file=url.protection' : 'W2A::EN::Tokenize'),
    # 'W2A::EN::NormalizeForms',
    # 'W2A::EN::FixTokenization',
    $self->gazetteer ? 'W2A::EN::GazeteerMatch trg_lang='.$self->trg_lang.' filter_id_prefixes="'.$self->gazetteer.'"' : (),
    $self->moses_xml ? 'W2A::EscapeMoses' : (),
    # TODO $self->truecase_moses ? 'W2A::TruecaseMoses' : ();
    $self->lowercase ? 'Util::Eval anode="$anode->set_form(lc $anode->form);"' : (),
    # $self->gazetteer_xml ? 'Util::Eval anode="my $form = $anode->form; if($form =~ /[><]/) {$form =~ s/</\&lt;/g; $form =~ s/>/\&gt;/g; $anode->set_form($form); $anode->set_no_space_after(0); ($anode->get_prev_node // $anode)->set_no_space_after(0); }"' : (),
    $self->gazetteer ? 'W2A::HideGazeteerItems trg_lang=' . $self->trg_lang . ($self->moses_xml ? ' moses_xml=1' : '') : (),
    $self->gazetteer && !$self->moses_xml ? 'Write::BundleWildAttributeDump attribute=gazeteer_translations  to=' . $self->gazeteer_translations_file : (),
    $self->tag && $self->tagger eq 'Morce' ? 'W2A::EN::TagMorce' . ($self->tagger_lemmatize ? ' lemmatize=1 ' : '') : (),
    $self->tag && $self->tagger eq 'MorphoDiTa' ? 'W2A::EN::TagMorphoDiTa' . ($self->tagger_lemmatize ? ' lemmatize=1 ' : '') : (),
    $self->tag && $self->fix_tags ? 'W2A::EN::FixTags' : (),
    $self->tag && $self->fix_tags ? 'W2A::EN::FixTagsImperatives' : (),
    $self->tag && !$self->tagger_lemmatize ? 'W2A::EN::Lemmatize' : (),
    $self->tag && $self->fix_tags && $self->domain eq 'IT' ? ' W2A::EN::QtHackTags' : (),
    $self->detokenize ? 'A2W::Detokenize remove_final_space=1' : 'A2W::ConcatenateTokens',
    $self->hideIT && $self->moses_xml ? 'A2W::ShowIT moses_xml=1 set_original_sentence=0' : (),
    $self->tag ? 'Write::AttributeSentences layer=a attributes=form,lemma,tag' : 'Write::Sentences join_resegmented=0',
    ;

    return $scen;
}

1;

__END__


=encoding utf-8

=head1 NAME

Treex::Scen::EN_Moses_preprocess - English preprocessing for Moses.
Especially useful in the Chiméra setup and/or in the IT domain setting.

=head1 SYNOPSIS

 # From command line
 treex Scen::EN_Moses_preprocess trg_lang=cs < ../source.txt > input.txt

=head1 DESCRIPTION

Treex analysis for Moses, parametrizable as to which púarts to run or not

=over

=item read in

=item sentence segmentation

=item hideIT

=item tokenization

=item gazeteers

=item tagging and lemmatization

=item writeout

=item moses_xml

Annotate HideIT and Gazzetteer items with Moses XML tags.
Also implies Moses entities escaping.

In most cases should be used with C<tokenize_moses> and C<lowercase> or C<truecase_moses>.

=item tokenize_moses

=item lowercase

=item truecase_moses

=back

=head1 PARAMETERS

=head2 domain (general, IT)

=head2 tagger (Morce, MorphoDiTa)

Morce = W2A::EN::TagMorce

MorphoDiTa = W2A::EN::TagMorphoDiTa

=head1 AUTHORS

Martin Popel <popel@ufal.mff.cuni.cz>
Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015-2016 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
