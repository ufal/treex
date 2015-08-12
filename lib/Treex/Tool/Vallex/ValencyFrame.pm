package Treex::Tool::Vallex::ValencyFrame;

use Moose;
use Treex::Core::Common;
use Treex::Core::Resource qw(require_file_from_share);
use MooseX::ClassAttribute;
use XML::LibXML;
use Treex::Tool::Vallex::FrameElement;

# Fill the default valency lexicon path here (where vallex.xml is located)
Readonly my $DEFAULT_LEXICON_PATH => 'data/resources/vallex/';

# The lemma of the current valency frame
has 'lemma' => ( isa => 'Str', is => 'ro', required => 1 );

# The part of speech
has 'pos' => ( isa => 'Str', is => 'ro', required => 1 );

# The individual frame elements (Treex::Tool::Vallex::FrameElement)
has 'elements' => ( isa => 'ArrayRef', is => 'ro', required => 1 );

# The language ID (two character string)
has 'language' => ( isa => 'Str', is => 'ro', required => 1 );

# The ID of the frame in the lexicon
has 'id' => ( isa => 'Str', is => 'ro' );

# A note given in the dictionary (such as a gloss)
has 'note' => ( isa => 'Str', is => 'ro' );

# An example given in the dictionary
has 'example' => ( isa => 'Str', is => 'ro' );

# the lexicon name, such as C<vallex.xml>
has 'lexicon' => ( isa => 'Str', is => 'ro' );

# A hash map of all the frame elements, according to their functor
has '_element_map' => ( isa => 'HashRef', is => 'ro', builder => '_build_element_map', lazy_build => 1 );

# A hash map of all the frame elements, according to their possible formemes
has '_form_map' => ( isa => 'HashRef', is => 'ro', builder => '_build_form_map', lazy_build => 1 );

# Loaded valency dictionaires cache
class_has '_loaded_dicts' => ( isa => 'HashRef', is => 'rw', default => sub { {} } );

# Constructor, converting the lexicon + id into lemma, pos and elements (i.e. loading data from lexicon).
around 'BUILDARGS' => sub {

    my $orig = shift;
    my $self = shift;

    # Build a hash reference
    my $params = $self->$orig(@_);

    # Find in the valency dictionary and parse
    if ( ( $params->{id} or $params->{ord} ) and $params->{lexicon} and !$params->{lemma} ) {

        my $xc = _get_xpath_context( $params->{lexicon} );
        my ($frame_xml) = $params->{id}
            ? $xc->findnodes( '//frame[@id=\'' . $params->{id} . '\'][1]' )
            : $xc->findnodes( '(//frame)[' . $params->{ord} . ']' );

        if ( !$frame_xml ) {
            log_warn( "The specified valency frame ID was not found: " . ( $params->{id} ? $params->{id} : $params->{ord} ) );
        }

        # Fill the valency frame from dictionary XML
        _fill_params_from_xml( $frame_xml, $params );
    }
    else {
        $params->{lemma} =~ s/ /_/g;
        if ( $params->{pos} !~ /^(n|v|adj|adv)$/ ) {
            log_warn("Non-standard POS for a valency frame, should be n, v, adj or adv.");
        }
    }

    # Otherwise keep the user-set members and die if some of them are missing
    return $params;
};

# Fill valency frame parameters from a XML context in the dictionary
sub _fill_params_from_xml {

    my ( $frame_xml, $params ) = @_;

    # Fill in lemma and POS (convert their format to correspond to usual TectoMT conventions)
    $params->{lemma} = $frame_xml->parentNode->parentNode->getAttribute('lemma');
    $params->{lemma} =~ s/ /_/g;
    $params->{pos} = lc( $frame_xml->parentNode->parentNode->getAttribute('POS') );
    $params->{pos} =~ s/^a$/adj/;
    $params->{pos} =~ s/^d$/adv/;

    # Fill in valency members
    $params->{elements} = [];
    foreach my $element ( $frame_xml->getElementsByTagName('element') ) {
        push(
            @{ $params->{elements} },
            Treex::Tool::Vallex::FrameElement->new( xml => $element, language => $params->{language} )
        );
    }

    # Fill in note and example
    $params->{note}    = join( ' ', map { $_->textContent } $frame_xml->getElementsByTagName('note') );
    $params->{example} = join( ' ', map { $_->textContent } $frame_xml->getElementsByTagName('example') );
}

# This is able to load the valency lexicon into the memory, or to retrieve an already loaded one.
# The XPath context for the lexicon is returned, as this is what's needed for the search by id or order
sub _get_xpath_context {

    my ($lexicon_name) = @_;
    my $xc;

    if ( !Treex::Tool::Vallex::ValencyFrame->_loaded_dicts->{$lexicon_name} ) {
        my $lexicon = XML::LibXML->load_xml( location => require_file_from_share( $DEFAULT_LEXICON_PATH . $lexicon_name ) );
        $lexicon->indexElements();
        Treex::Tool::Vallex::ValencyFrame->_loaded_dicts->{$lexicon_name} = XML::LibXML::XPathContext->new($lexicon);
    }
    return Treex::Tool::Vallex::ValencyFrame->_loaded_dicts->{$lexicon_name};
}

# Stupid escaping function needed since there's no other way to escape quotes in XPath
sub _xpath_escape_quotes {
    my ($str) = @_;

    # solve simple cases (actually, most of the cases) where one type of quotes is used at most
    return '"' . $str . '"' if ( $str !~ /"/ );
    return "'" . $str . "'" if ( $str !~ /'/ );

    # solve strings with both types of quotes using the 'concat' function
    my @sp = split /(["'])/, $str;
    $str = 'concat(';
    for ( my $i = 0; $i < @sp - 1; $i += 2 ) {
        $str .= ',' if ( $i > 0 );
        $str .= ( $sp[ $i + 1 ] eq '"' ? "'" : '"' ) . $sp[$i] . $sp[ $i + 1 ] . ( $sp[ $i + 1 ] eq '"' ? "'" : '"' );
    }
    $str .= ',"' . $sp[-1] . '")';
    return $str;
}

# Retrieve all frames for the given lemma
sub get_frames_for_lemma {

    my ( $lexicon_name, $language, $lemma, $pos ) = @_;
    my $xc = _get_xpath_context($lexicon_name);
    my @frames;
    my @found;

    $lemma = _xpath_escape_quotes($lemma);
    if ($pos) {
        $pos =~ s/^adj$/a/i;
        $pos =~ s/^adv$/d/i;
        $pos = _xpath_escape_quotes( uc $pos );

        @found = $xc->findnodes("//word[\@lemma=$lemma and \@POS=$pos]//frame");
    }
    else {
        @found = $xc->findnodes("//word[\@lemma=$lemma]//frame");
    }

    foreach my $frame_xml (@found) {

        my $params = { language => $language, lexicon => $lexicon_name, id => $frame_xml->getAttribute('id') };
        _fill_params_from_xml( $frame_xml, $params );
        push @frames, Treex::Tool::Vallex::ValencyFrame->new($params);
    }
    return @frames;
}

sub get_frame_by_id {

    my ( $lexicon_name, $language, $id ) = @_;
        
    my $xc = _get_xpath_context($lexicon_name);
    my ($frame_xml) = $xc->findnodes("//frame[\@id='$id']");
    return if (!$frame_xml);
    my $params = { language => $language, lexicon => $lexicon_name, id => $id }; 
    _fill_params_from_xml( $frame_xml, $params );
    return Treex::Tool::Vallex::ValencyFrame->new($params);
}

# This constructs the hashmap of the frame elements by their functor
sub _build_element_map {

    my ($self) = @_;
    my %map;

    foreach my $param ( @{ $self->elements } ) {
        $map{ $param->functor } = $param;
    }
    return \%map;
}

# This constructs the hashmap of frame elements by their possible forms
sub _build_form_map {

    my ($self) = @_;
    my %map;

    foreach my $element ( @{ $self->elements } ) {
        foreach my $form ( @{ $element->forms_list } ) {
            $map{$form} = [] if ( !$map{$form} );
            push @{ $map{$form} }, $element;
        }
    }
    return \%map;
}

# Return the frame element with the specified functor, or undef
sub functor {
    my ( $self, $functor ) = @_;

    return $self->_element_map->{$functor};
}

# Return all frame elements that can have the given formeme, or undef
sub elements_have_form {
    my ( $self, $formeme ) = @_;

    return $self->_form_map->{$formeme} if ( defined $self->_form_map->{$formeme} );
    return [];
}

# Convert the frame to a string
sub to_string {
    my ($self, $params) = @_;
    my $ret = $self->lemma . '-' . $self->pos;

    if ($params and $params->{id}){
        $ret .= ' ' . ($self->id // '');
    } 
    if ($params and $params->{note}){
        $ret .= ' (' . ($self->note // '') . ')';
    } 
    $ret .= ': ' . join( ' ', map { $_->to_string($params) } @{ $self->elements } );
    $ret =~ s/\n/ /g;  # remove newlines to avoid problems in further processing
    return $ret;
}

1;
__END__

=encoding utf-8

=head1 NAME 

Treex::Tool::Vallex::ValencyFrame

=head1 DESCRIPTION

This represents a single valency frame of a tectogrammatical node, containing its lemma, part of speech
and the individual elements (as L<Treex::Tool::Vallex::FrameElement> objects). A valency frame may be created
either directly using the values, or from an XML valency dictionary, such as the 
L<PDT-Vallex|http://ufal.mff.cuni.cz/pdt2.0/data/pdt-vallex/vallex.xml> Czech valency lexicon. 

=head1 SYNOPSIS

    # create a frame from scratch
    my $frame = Treex::Tool::Vallex::ValencyFrame->new({lemma => 'hlad', pos => 'n', elements => [], language => 'cs' });

    # create a frame from the valency dictionary
    $frame = Treex::Tool::Vallex::ValencyFrame->new( {ord => 3, lexicon => 'vallex.xml', language => 'cs'} );
    $frame = Treex::Tool::Vallex::ValencyFrame->new( {id => 'v-w3f1', lexicon => 'vallex.xml', language => 'cs'} );
   
    # get all frames for the specified lemma from the valency dictionary
    my @frames = Treex::Tool::Vallex::ValencyFrame::get_frames_for_lemma( 'vallex.xml', 'cs', 'být', 'v' );
    
    # print the frame
    $frame->to_string();

    # access the individual frame elements (Treex::Tool::Vallex::FrameElement)  
    my $element = $frame->functor('ACT'); # will be undef if the frame does not have such functor
    $element = $frame->elements()->[0];

=head1 METHODS

=over

=item C<elements>

    $element = $frame->elements->[0];

A direct access to all elements of the valency frame (as an array of L<Treex::Tool::Vallex::FrameElement> objects).

=item C<functor>

    $element = $frame->functor('ACT');
    
This returns a L<Treex::Tool::Vallex::FrameElement> object which represents the element of this valency
frame with the given functor, or undef, if no such functor is found in the frame.

=item C<id>

The id of the valency frame in the valency lexicon, such as C<v-w3f1> (if creating the frame from scratch, this may be blank).

=item C<language>

The language of the valency frame (two-character code, such as C<cs>).

=item C<lemma>

The lemma for this valency frame. The lemmas are normalized according to the PDT/TectoMT t-layer convention
(with underscores instead of spaces).

=item C<lexicon>

The name of the valency lexicon, such as C<vallex.xml>, usually taken directly from the C<val_frame.rf>
attribute of a t-node.

=item C<new>

    $frame = Treex::Tool::Vallex::ValencyFrame->new({lemma => 'hlad', pos => 'n', elements => [], language => 'cs' });
    $frame = Treex::Tool::Vallex::ValencyFrame->new( {ord => 3, lexicon => 'vallex.xml', language => 'cs'} );
    $frame = Treex::Tool::Vallex::ValencyFrame->new( {id => 'v-w3f1', lexicon => 'vallex.xml', language => 'cs'} );

This creates a new valency frame. It may be created either from scratch, using some pre-filled values,
or directly from the valency lexicon data.

If the frame is created using pre-filled values, the C<lemma>, C<pos>, C<elements> and C<language> must be given.
The C<id> and C<lexicon> are left blank.

If the frame is created using the lexicon, the C<lexicon> name and C<id> from the C<val_Frame.rf> must be given,
or the C<lexicon> name and C<ord> -- order of the frame globally within the lexicon. If C<ord> is given, it is then
converted to the frame C<id>. All the other values, i.e. C<lemma>, C<pos> and C<elements>, are then filled in from the
valency lexicon. 

=item C<pos>

The semantic part of speech (sempos) for this valency frame. The standard values are: I<n>, I<adj>, I<v>, I<adv>.  

=item C<to_string($params)>

This returns a string version of the valency frame in a format that corresponds to the following example:

    adaptovat-v: ACT[n:1] PAT[n:4] (ORIG[n:z+2]) (EFF[n:do+2, n:na+4])

The lemma and POS stand at the beginning and are separated with a dash. Then, after a colon, the list of all frame
elements follows (according to the string versions of the individual frame elements).   

If C<$params> is set, it must be a HASHREF. Some values in this hashref change the behavior of C<to_string>:

* Setting 'id' to 1 will print the frame ID.

* Setting 'note' to 1 will print any notes associated with the frame in the lexicon.

* Setting 'formemes' to 0 will not print formemes in square brackets. 


=back

=head1 CLASS METHODS

=over

=item get_frames_for_lemma( $lexicon_name, $language, $lemma, $pos )

This returns a list of all frames with the specified lemma and part-of-speech found in the specified lexicon.

=item get_frame_by_id( $lexicon_name, $language, $id )

Returns the frame with the given ID from the specified lexicon (or undef if not found).

=back

=head1 TODO

=over

=item *

Keep also links to all frames with the same language, lexicon and ID and do not instantiate them repeatedly?

=item *

Somehow get rid of the compulsory Vallex path specification in a code constant (C<DEFAULT_LEXICON_PATH>)?

=item *

The possibility to create frame elements from strings?

=back

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011-2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
