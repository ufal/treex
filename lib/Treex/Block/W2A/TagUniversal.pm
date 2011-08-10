package Treex::Block::W2A::TagUniversal;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has module => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has _tagger => (
    is => 'rw',
);

sub BUILD {
    my ( $self, $arg_ref ) = @_;
    my $module = $self->module;
    eval "use $module;1" or log_fatal "Can't use $module";
    my $tagger = eval "$module->new(\$arg_ref);" or log_fatal "Can't load $module";
    if ( !$tagger->does('Treex::Tool::Tagger::Role') ) {
        log_fatal "$module does not implement Treex::Tool::Tagger::Role";
    }
    $self->_set_tagger($tagger);
    return;
}

sub process_atree {
    my ( $self, $atree ) = @_;

    my @forms = map { $_->form } $atree->get_descendants();
    my ( $tags, $lemmas ) = $self->_tagger->tag_and_lemmatize_sentence(@forms);

    # fill tags and lemmas
    foreach my $a_node ( $atree->get_descendants() ) {
        $a_node->set_tag( shift @$tags );
        $a_node->set_lemma( shift @$lemmas );
    }

    return 1;
}

1;

__END__

=head1 NAME

Treex::Block::W2A::TagUniversal

=head1 SYNOPSIS

  # in scenario 
  W2A::TagUniversal module=Treex::Tool::Tagger::NameOfMyTagger
  
  # from command line 
  echo "Hello there" | treex -Len Read::Sentences W2A::Tokenize \
   W2A::TagUniversal module=Treex::Tool::Tagger::Simple::XY \
   Util::Eval anode='print $anode->form. "/" . $anode->tag . "/" . $anode->lemma .  "\n"'

=head1 COPYRIGHT AND LICENCE

Copyright 2011 Martin Popel

This module is free software;
you can redistribute it and/or modify it under the same terms as Perl itself.
