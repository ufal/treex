#
# This is a copy of the Arff::Util package from CPAN with a lot of fixes and improvements. I will send them to the
# original author so that he can add them into CPAN.
#
# Ondrej Dusek, 2011/04/06
#
package Treex::Tool::IO::Arff;

use Moose;
use autodie;    # die on I/O error

#use Data::Dumper;
use String::Util ':all';
use Scalar::Util 'looks_like_number';

=head1 NAME

Arff::Util - ARFF files processing utilities.
This is a moose-based class.

=head1 VERSION

Version 1.1

=cut

our $VERSION = '1.1';

=head1 SYNOPSIS

Quick summary of what the module does.

  use ARFF::Util;

  my $arff_object = ARFF::Util->new();
  # load .arff formatted file from a path or an open handle (reference) into the buffer, and return a pointer to buffer
  $arff_hash = $arff_object->load_arff($file_address);
  
  # check all attribute types (fill in missing attributes from the data, if $check_presence is non-zero
  # default to string attributes if $string is non-zero, nominal otherwise
  $arff_object->prepare_headers($arff_hash, $check_presence, $string);
  
  # save the given buffer into an .arff formatted file, to a path or an open handle (reference)
  $arff_object->save_arff($arff_hash, $file_address);

=head1 DESCRIPTION

ARFF::Util provides a collection of methods for processing ARFF formatted files.
"An ARFF (Attribute-Relation File Format) file is an ASCII text file that describes a list of instances sharing a set of attributes."
for more information about ARFF format visit http://www.cs.waikato.ac.nz/~ml/weka/arff.html

=head1 EXPORT



=head1 Object Attributes

=head2 relation

 This is a buffer hash
 Structure of hash:

 relation -> {
        relation_name => name, 
		attributes => [
				{
					attribute_name => x1,
					attribute_type => x2,
				},...
			      ],
		records    => [
				{
					attribute_name1 => value1,
					attribute_name2 => value2,...
				},...
			      ],
		data_record_count => x
	      }
=cut

has relation => (
    is      => 'rw',
    isa     => 'HashRef',
    default => sub {
        {
            attributes        => [],
            records           => [],
            data_record_count => 0
        };
        }
);

=head2 error_count

Number of errors occured during the parsing or saving

=cut

has error_count => (
    is      => 'rw',
    default => 0
);

=head2 debug_mode

Set it to one to see detail info

=cut

has debug_mode => (
    is      => 'rw',
    default => 0
);

=head1 FUNCTIONS

=head2 load_arff( $arff_file )

Load ARFF data from a file or an open input handle (will not close the handle). 

=cut

sub load_arff {

    my ( $self, $arff_file ) = @_;
    my $status = 'header';

    my $attribute_count = 0;
    my $line_counter    = 1;
    my $relation        = $self->relation;
    my $io;

    if ( ref $arff_file ne 'IO' ) {
        open( $io, "<:utf8", $arff_file );
    }
    else {
        $io        = $arff_file;
        $arff_file = '<HANDLE>';
    }

    if ( $self->debug_mode ) {
        print STDERR "Loading $arff_file ...\n";
    }
    while ( my $current_line = <$io> )
    {
        $current_line =~ s/^\s+//;
        $current_line =~ s/\s*\r?\n?$//;

        # comments (skip)
        if ( $current_line =~ /^\s*%/i ) { 
        }
        # relation name
        elsif ( $current_line =~ /^\s*\@RELATION\s+(\S*)/i ) {
            $relation->{relation_name} = $1;
        }
        # attribute definitions 
        elsif ( $current_line =~ /^\s*\@ATTRIBUTE\s+(\S*)\s+(\S.*)\s*$/i ) {
            
            if ( !$relation->{attributes} ) {
                $relation->{attributes} = [];
            }
            push @{ $relation->{"attributes"} }, { "attribute_name" => $1, "attribute_type" => $2 };
            $attribute_count++;
        }
        # data start
        elsif ( $current_line =~ /^\s*\@DATA(\.*)/i ) {
            $status = 'data';
        }
        # data lines
        elsif ( $status eq 'data' && $current_line ne '' ) {
            $self->add_data_line( $line_counter, $current_line );
        }
        $line_counter++;
    }
    if ( $arff_file ne '<HANDLE>' ) {
        close($io);
    }

    $relation->{"attribute_count"}   = $attribute_count;

    if ( $self->debug_mode ) { 
        require Devel::Size;
        Devel::Size->import( qw(size total_size) );

        print STDERR "$arff_file loaded with " . $self->error_count . " error(s).\n";
        print STDERR "Buffer size: " . total_size($relation) . " bytes\n";
    }
    return $relation;
}

=head2 add_data_line( $line_counter, $line_text )

Add one data line in ARFF format to the current relation (must conform to the header format).

=cut

sub add_data_line {

    my ( $self, $line_counter, $line ) = @_;
    my $relation = $self->relation;
            
    if ( !$relation->{'records'} ) {
        $relation->{'records'} = [];
        $relation->{'data_record_count'} = 0;
    }
    
    #log_msg("extracting data $current_line");
    my ($cur_record) = $self->_parse_line( $line_counter, $line );

    if ($cur_record) {
        push @{ $relation->{"records"} }, $cur_record;
        $relation->{'data_record_count'}++;
    }
}


# Clear all records 
sub clear_data {
    
    my ( $self ) = @_;
    my $relation = $self->relation;
    
    $relation->{'data_record_count'} = 0;
    $relation->{'records'} = [];
}


# Parse an ARFF data line, return all fields it contains. Both single and double quotes
# are allowed, unquoted quotation marks are treated as missing values.
sub _parse_line {

    my ( $self, $line_num, $line ) = @_;
    my %values;
    my $attributes = $self->relation->{"attributes"};

    if ( $line =~ m/^{/ ) {    # sparse instance

        $line =~ s/^{//;
        $line =~ s/}$/,/;
        $self->_zero_fill( \%values );

        while ( $line =~ m/([0-9]+)\s+([^"'\s][^,]*|'[^']*(\\'[^']*)*'|"[^"]*(\\"[^"]*)*"),/g ) {

            my ( $attr_num, $field ) = ( $1, $2 );

            if ( !$attributes->[$attr_num] ) {
                if ( $self->debug_mode ) {
                    print STDERR "Line $line_num : Invalid data record: $line Attribute $attr_num out of range\n";
                }
                return;
            }

            if ( $field eq '?' ) {    # undefined value, delete the pre-set zero
                delete( $values{ $attributes->[$attr_num]->{'attribute_name'} } );
            }
            elsif ( $field =~ m/^['"].*['"]$/ ) {    # quoted value
                $field = substr( $field, 1, length($field) - 2 );    # unquote
                $field =~ s/\\([\n\r'"\\\t%])/$1/g;                  # unescape (same as weka.core.Utils)
                $values{ $attributes->[$attr_num]->{"attribute_name"} } = $field;
            }
            else {                                                   # unquoted value (trim whitespace)
                $field =~ s/^\s+//;
                $field =~ s/\s+$//;
                $values{ $attributes->[$attr_num]->{"attribute_name"} } = $field;
            }
        }
    }
    else {                                                           # dense instance
        my $values_num = 0;
        $line .= ',';     
        while ( $line =~ m/([^"'][^,]*|'[^']*(\\'[^']*)*'|"[^"]*(\\"[^"]*)*"),/g ) {

            my $field = $1;
            
            if ( $field eq '?' ) {                                   # undefined value, leave as is
            }
            elsif ( $field =~ m/^['"].*['"]$/ ) {                    # quoted value
                $field = substr( $field, 1, length($field) - 2 );    # unquote
                $field =~ s/\\([\n\r'"\\\t%])/$1/g;                  # unescape (same as weka.core.Utils)
                $values{ $attributes->[$values_num]->{"attribute_name"} } = $field;
            }
            else {                                                   # unquoted value (trim whitespace)
                $field =~ s/^\s+//;
                $field =~ s/\s+$//;            
                $values{ $attributes->[$values_num]->{"attribute_name"} } = $field;
            }
            $values_num++;
        }
        if ( $values_num != @{$attributes} ) {

            if ( $self->debug_mode ) {
                print STDERR "Line $line_num : Invalid data record: $line Contains $values_num, Expected"
                    . scalar( @{$attributes} ) . "\n";
            }
            return;                                                  # return undef on error
        }
    }
    return {%values};                                                # return all the values if no error is encountered
}

# insert a zero value for all numeric and nominal attributes, empty (but defined) value for string attributes
# (knowing that string attributes in sparse ARFF files cause a lot of problems anyway)
sub _zero_fill {

    my ( $self, $values ) = @_;

    foreach my $attrib ( @{ $self->relation->{"attributes"} } ) {

        # numeric attribute
        if ( $attrib->{'attribute_type'} =~ m/^(numeric|real|integer)$/i ) {
            $values->{ $attrib->{'attribute_name'} } = 0;
        }

        # nominal attribute
        elsif ( $attrib->{'attribute_type'} =~ m/^{([^"'][^,]*|'[^']*(\\'[^']*)*'|"[^"]*(\\"[^"]*)*"),/ ) {
            $values->{ $attrib->{'attribute_name'} } = $1;
        }

        # string attribute
        else {
            $values->{ $attrib->{'attribute_name'} } = '';
        }
    }

    return;
}

=head2 save_arff( $arff_relation, $file, $print_headers = 1 )

Save the given buffer into an ARFF file (or an open file handle).

=cut

sub save_arff {

    my ( $self, $buffer, $arff_file, $print_headers ) = @_;
    my $io;

    if ( !defined($print_headers) ) {
        $print_headers = 1;
    }

    if ( !ref($arff_file) ) {
        open( $io, '>utf8', $arff_file );
    }
    else {
        $io        = $arff_file;
        $arff_file = '<HANDLE>';
    }

    my $record_count = 0;

    if ( $self->debug_mode ) {
        print STDERR "Writing buffer ...\n";
    }

    if ($print_headers) {
        if ( $buffer->{relation_name} ) {
            print {$io} q/@RELATION / . $buffer->{relation_name} . "\n";
        }
        print {$io} "\n\n";
    }

    if ( $buffer->{attributes} ) {

        if ($print_headers) {
            foreach my $attribute ( @{ $buffer->{attributes} } ) {                
                print {$io} q/@ATTRIBUTE / . $attribute->{attribute_name} . q/ / . $attribute->{attribute_type} . "\n";
            }
            print {$io} "\n\n";
            print {$io} "\@DATA\n\n";
        }

        if ( $buffer->{records} ) {
            
            my @lines = $self->get_data_lines($buffer);
            
            foreach my $line (@lines){
                print {$io} $line, "\n";
                $record_count++;
            }
        }
    }
    if ( $arff_file ne '<HANDLE>' ) {
        close($io);
    }

    if ( $self->debug_mode ) {
        eval("use Devel::Size qw(size total_size)");

        print STDERR "Buffer saved to $arff_file with " . $self->error_count . " error(s).\n";
        print STDERR "Buffer size: " . total_size($buffer) . " bytes\n";
        print STDERR "Data rows count: " . $record_count . "\n";
    }

    return 1;
}

=head2 save_arff( $arff_relation )

Return an array of ARFF format data lines, given a relation object.

=cut
sub get_data_lines {
    
    my ($self, $buffer) = @_;
    my @lines;

    foreach my $record ( @{ $buffer->{"records"} } ) {
        my @record_fields = ();
        foreach my $attribute ( @{ $buffer->{"attributes"} } ) {

            if ( defined( $record->{ $attribute->{attribute_name} } ) ) {
                push @record_fields, $record->{ $attribute->{attribute_name} };
            }
            else {
                push @record_fields, undef;
            }
        }

        push @lines, $self->_compose_line(@record_fields);
    }
    return @lines;    
}

# Compose an ARFF data line out of given fields. Quote any fields that might need it,
# save undefined fields as unquoted quotation marks.
sub _compose_line {

    my $self   = shift;
    my @fields = @_;
    my $line   = '';

    foreach my $field (@fields) {

        if ( !defined($field) ) {
            $line .= '?,';
        }
        elsif ( $field eq '' or $field =~ m/[\n\r'"\\\t%{},? ]/ ) {    # we need quotes

            $field =~ s/([\n\r'"\\\t%])/\\$1/g;                        # escape (same as weka.core.Utils)
            $line .= "'$field',";
        }
        else {
            $line .= "$field,";
        }
    }
    return substr( $line, 0, length($line) - 1 );                      # leave last comma out
}


=head2 prepare_headers

Prepare the ARFF file headers for writing: determine between nominal (or string) and numeric attributes, fill in missing values
for nominal attributes. All pre-set attribute type settings are kept (only missing values for nominal attributes filled). 

=cut

sub prepare_headers {

    my ( $self, $buffer, $ensure_attribs, $string_default ) = @_;

    # there's no work with no data
    return if !$buffer->{records} or @{ $buffer->{records} } == 0;

    if ($ensure_attribs) {
        $self->_ensure_attributes($buffer);
    }

    $self->_set_attribute_types( $buffer, $string_default );
}

# Check if all attributes are present.
sub _ensure_attributes {

    my ( $self, $buffer ) = @_;

    # create the attributes declarations if not already done
    if ( !$buffer->{attributes} ) {
        $buffer->{attributes} = [];
    }

    my %attribs;
    foreach my $attribute ( @{ $buffer->{attributes} } ) {
        $attribs{ $attribute->{attribute_name} } = $attribute;
    }

    # now create the missing attributes
    foreach my $record ( @{ $buffer->{records} } ) {

        foreach my $attr_name ( sort keys %{$record} ) {
            if ( !$attribs{$attr_name} ) {

                my $new_attr = { attribute_name => $attr_name };
                push @{ $buffer->{attributes} }, $new_attr;
                $attribs{$attr_name} = $new_attr;
            }
        }
    }
}

# Detect attribute types by collecting all their values and testing whether they are numeric.
sub _set_attribute_types {

    my ( $self, $buffer, $string_default ) = @_;

    foreach my $attr ( @{ $buffer->{attributes} } ) {

        # skip pre-set numeric and string attributes
        next if ( $attr->{attribute_type} and ( $attr->{attribute_type} eq 'NUMERIC' or $attr->{attribute_type} eq 'STRING' ) );
        
        # set all to string if string_default is imposed
        if (!$attr->{attribute_type} && $string_default){
            $attr->{attribute_type} = 'STRING';
        }

        my %values;

        # keep pre-set values
        if ( $attr->{attribute_type} and $attr->{attribute_type} =~ m/^{.*}$/ ) {
            my $val_list = $attr->{attribute_type};
            $val_list =~ s/^{(.*)}$/$1/;
            %values = map { $_ => 1 } $self->_parse_line($val_list);
        }

        # find all other values
        for my $record ( @{ $buffer->{records} } ) {
            if ( defined( $record->{ $attr->{attribute_name} } ) ) {
                $values{ $record->{ $attr->{attribute_name} } } = 1;
            }
        }

        # determine the type (numeric or nominal)
        if ( !$attr->{attribute_type} ) {
            my $numeric = 1;

            for my $value ( keys %values ) {
                if ( !looks_like_number($value) ) {
                    $numeric = 0;
                    last;
                }
            }
            if ($numeric) {
                $attr->{attribute_type} = 'NUMERIC';
            }
        }
        if ( !$attr->{attribute_type} or $attr->{attribute_type} =~ m/^{.*}$/ ) {
            $attr->{attribute_type} = '{' . $self->_compose_line( sort keys %values ) . '}';
        }
    }

}

=head1 AUTHOR

Ehsan Emadzadeh, C<< <ehsan0emadzadeh at yahoo.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-arff-util at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Arff-Util>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can contact me: eemadzadeh [at] gmail  

or

You can find documentation for this module with the perldoc command.

    perldoc Arff::Util


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Arff-Util>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Arff-Util>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Arff-Util>

=item * Search CPAN

L<http://search.cpan.org/dist/Arff-Util/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 COPYRIGHT & LICENSE

Copyright 2008 Ehsan Emadzadeh, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut

1;    # End of Arff::Util
