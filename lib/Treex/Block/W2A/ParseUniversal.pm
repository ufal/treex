package Treex::Block::W2A::ParseUniversal;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has module => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has _parser => (
    is => 'rw',
);

sub BUILD {
    my ( $self, $arg_ref ) = @_;
    my $module = $self->module;
    eval "use $module;1" or log_fatal "Can't use $module";
    my $parser = eval "$module->new(\$arg_ref);" or log_fatal "Can't load $module";
    if ( !$parser->does('Treex::Tool::Parser::Role') ) {
        log_fatal "$module does not implement Treex::Tool::Parser::Role";
    }
    $self->_set_parser($parser);
    return;
}

sub process_atree {
    my ( $self, $atree ) = @_;
    my @nodes   = $atree->get_descendants();
    my @forms   = map { $_->form } @nodes;
    my @lemmas  = map { $_->lemma } @nodes;
    my @tags    = map { $_->tag } @nodes;
    my ($parents_rf, $afuns_rf) = $self->_parser->parse_sentence( \@forms, \@lemmas, \@tags );

    # root-note has ord=0 and should be indexed at $nodes[0]
    unshift @nodes, $atree;

    # set parents
    foreach my $i ( 1 .. $#nodes ) {
        $nodes[$i]->set_parent( $nodes[ $parents_rf->[ $i - 1 ] ] );
        $nodes[$i]->set_afun( $afuns_rf->[ $i - 1 ] ) if $afuns_rf;
    }
    return;
}

1;

__END__

=head1 NAME

Treex::Block::W2A::ParseUniversal

=head1 SYNOPSIS

  # in scenario 
  W2A::ParseUniversal module=Treex::Tool::Parser::NameOfMyParser
  
  # from command line 
  echo "Hello there" | treex -Len Read::Sentences W2A::Tokenize \
   W2A::TaggerUniversal module=Treex::Tool::Tagger::Simple::XY \
   W2A::ParseUniversal module=Treex::Tool::Parser::Simple::XY \
   Util::Eval anode='print $anode->form. "/" . $anode->parent->ord . "\n"'

=head1 COPYRIGHT AND LICENCE

Copyright 2011 Martin Popel

This module is free software;
you can redistribute it and/or modify it under the same terms as Perl itself.
