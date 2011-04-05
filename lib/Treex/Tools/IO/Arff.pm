#
# This is a copy of the Arff::Util package from CPAN with some bugfixes. I am planning to contribute the fixes
# to CPAN and remove this file in the future.
#
# Ondrej Dusek, 2011/03/25
#
package Treex::Tools::IO::Arff;

use Moose;

use Data::Dumper;
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
  # load .arff formatted file into the buffer, and return pointer to buffer
  $arff_hash = $arff_object->load_arff($file_address);
  
  # save given buffer into the .arff formatted file
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
		attributes => [
				{
					attribute_name => x1,
					attribute_type => x2,
				},...
			      ]
		records    => [
				{
					attribute_name1 => value1,
					attribute_name2 => value2,...
				},...
			      ]
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

=head2 load_arff

Get arff file path and load it in buffer

=cut

sub load_arff {
    my ( $self, $arff_file ) = @_;
    my $status = q/normal/;
    if ( $self->debug_mode ) {
        print "Loading $arff_file ...\n";
    }
    my $record_count    = 0;
    my $attribute_count = 0;
    my $line_counter    = 1;
    my $relation        = $self->relation;

    local *FILE;
    open( FILE, $arff_file ) or die $!;
    while ( my $current_line = <FILE> )
    {
        $current_line = trim($current_line);

        #Check for comments
        if ( $current_line =~ /^\s*%/i )
        {
            $status = q/comment/;
        }
        elsif ( $current_line =~ /^\s*\@RELATION\s+(\S*)/i )
        {
            $relation->{relation_name} = $1;
        }
        elsif ( $current_line =~ /^\s*\@ATTRIBUTE\s+(\S*)\s+(\S*)/i )
        {
            if ( !$relation->{attributes} ) {
                $relation->{attributes} = [];
            }
            my $attribute = { "attribute_name" => $1, "attribute_type" => $2 };
            my $attributes = $relation->{"attributes"};

            #log_msg(Dumper $attribute);

            push @$attributes, $attribute;
            $attribute_count++;
        }
        elsif ( $current_line =~ /^\s*\@DATA(\.*)/i )
        {
            $status = q/data/;
        }
        elsif ( $status eq q/data/ && $current_line ne q// ) {
            if ( !$relation->{"records"} ) {
                $relation->{"records"} = [];
            }

            #log_msg("extracting data $current_line");
            my @data_parts = $self->_parse_line($current_line);    # split(/,/, $current_line);

            my $attributes = $relation->{"attributes"};
            my $records    = $relation->{"records"};

            my $cur_record = {};

            #log_msg("DATA PARTS".Dumper @data_parts);
            if ( scalar @data_parts == $attribute_count ) {
                for ( my $i = 0; $i <= $#data_parts; $i++ )
                {
                    $cur_record->{ $$attributes[$i]->{"attribute_name"} } = trim( $data_parts[$i] );
                }

                #log_msg("parts: ".$#data_parts);
                $record_count++;
                push @$records, $cur_record;
            }
            else
            {
                if ( $self->debug_mode ) {
                    print "Line $line_counter : Invalid data record: $current_line Contains " . ( scalar @data_parts ) . " Expected $attribute_count\n";
                }
                $self->error_count( $self->error_count + 1 );
            }

        }
        $line_counter++;
    }

    $relation->{"data_record_count"} = $record_count;
    $relation->{"attribute_count"}   = $attribute_count;

    if ( $self->debug_mode ) {
        eval("use Devel::Size qw(size total_size)");

        print "$arff_file loaded with " . $self->error_count . " error(s).\n";
        print "Buffer size: " . total_size($relation) . " bytes\n";
    }
    $self->relation($relation);
    return $relation;
}


# Parse an ARFF data line, return all fields it contains. Both single and double quotes
# are allowed, unquoted quotation marks are treated as missing values.
sub _parse_line {

    my ( $self, $line ) = @_;
    my @fields;
    
    $line .= ',';
    while ($line =~ m/([^"'][^,]*|'[^']*(\\'[^'])*'|"[^"]*(\\"[^"])*"),/g){
        
        my $field = $1;
        
        if ($field eq '?'){ # undefined value
            push(@fields, undef);
        }
        elsif ($field =~ m/^['"].*['"]$/ ){ # quoted value
            $field = substr($field, 1, length($field) - 2); # unquote
            $field =~ s/\\(['\\])/$1/g; # unescape 
            push(@fields, $field);
        }
        else { # unquoted value
            push(@fields, $field);
        }
    }
    return @fields;
}

# Compose an ARFF data line out of given fields. Quote any fields that might need it,
# save undefined fields as unquoted quotation marks.
sub _compose_line {
    
    my $self = shift;
    my @fields = @_;
    my $line = '';
    
    foreach my $field (@fields){
        
        if (!defined($field)){
            $line .= '?,';
        }
        elsif ($field eq '' or $field =~ m/[\\'"?]/){ # we need quotes
            $field =~ s/([\\'])/\\$1/g; # escape
            $line .= "'$field',";
        }
        else {
            $line .= "$field,";
        }
    }
    return substr($line, 0, length($line) - 1); # leave last comma out
}

=head2 save_arff

Save given buffer into the .arff formatted file. 

=cut

sub save_arff {
    my ( $self, $buffer, $arff_file ) = @_;

    local *FILE;

    open( FILE, ">$arff_file" );

    my $record_count = 0;

    if ( $self->debug_mode ) {
        print "Writing buffer to $arff_file ...\n";
    }

    if ( $buffer->{relation_name} )
    {
        print FILE q/@RELATION / . $buffer->{relation_name} . "\n";
    }
    print FILE "\n";
    print FILE "\n";

    if ( $buffer->{attributes} ) {
        foreach my $attribute ( @{ $buffer->{"attributes"} } ) {
            print FILE q/@ATTRIBUTE / . $attribute->{attribute_name} . q/ / . $attribute->{attribute_type} . "\n";
        }
        print FILE "\n";
        print FILE "\n";

        if ( $buffer->{records} ) {
            print FILE "\@DATA\n";
            print FILE "\n";

            foreach my $record ( @{ $buffer->{"records"} } ) {
                my @record_fields = ();
                foreach my $attribute ( @{ $buffer->{"attributes"} } ) {
                    
                    if ( $record->{ $attribute->{attribute_name} } ) {
                        push @record_fields, $record->{ $attribute->{attribute_name} };
                    }
                    else {
                        push @record_fields, undef;
                    }
                }

                print FILE $self->_compose_line(@record_fields) . "\n";
                $record_count++;
            }
        }
    }

    if ( $self->debug_mode ) {
        eval("use Devel::Size qw(size total_size)");

        print "Buffer saved to $arff_file with " . $self->error_count . " error(s).\n";
        print "Buffer size: " . total_size($buffer) . " bytes\n";
        print "Data rows count: " . $record_count . "\n";
    }

    return 1;
}


=head2 prepare_headers

Prepare the ARFF file headers for writing: determine between nominal and numeric attributes, fill in missing values
for nominal attributes. All pre-set attribute type settings are kept (only missing values for nominal attributes filled). 

=cut

sub prepare_headers {
    
    my ($self, $buffer) = @_;
            
    # there's no work with no data
    return if !$buffer->{records} or @{ $buffer->{records} } == 0;
       
    if ( !$buffer->{attributes} ){ # create the attributes declarations if not already done
        $buffer->{attributes} = [];
    }
    
    my %attribs;
    foreach my $attribute ( @{ $buffer->{attributes} } ){
        $attribs{ $attribute->{attribute_name} } = $attribute;
    }    

    # check if all needed attributes are present
    foreach my $record ( @{ $buffer->{records} } ){
                        
        foreach my $attr_name (sort keys %{ $record } ){
            if ( ! $attribs{$attr_name} ){
                            
                my $new_attr = { attribute_name => $attr_name };
                push @{ $buffer->{attributes} }, $new_attr;
                $attribs{$attr_name} = $new_attr;        
            }
        }
    }
    
    $self->_set_attribute_types($buffer);       
}


# detect attribute types by collecting all their values and testing whether they are numeric
sub _set_attribute_types {

    my ($self, $buffer) = @_;

    foreach my $attr (@{ $buffer->{attributes} }){

        # skip pre-set numeric and string attributes        
        next if ($attr->{attribute_type} and ($attr->{attribute_type} eq 'NUMERIC' or $attr->{attribute_type} eq 'STRING'));
        
        my %values;
        
        # keep pre-set values
        if ($attr->{attribute_type} and $attr->{attribute_type} =~ m/^{.*}$/){
            my $val_list = $attr->{attribute_type};
            $val_list =~ s/^{(.*)}$/$1/;             
            %values = map { $_ => 1 } $self->_parse_line($val_list); 
        }

        # find all other values
        for my $record (@{ $buffer->{records} }){
            if ($record->{ $attr->{attribute_name} }){
                $values{ $record->{ $attr->{attribute_name} } } = 1;
            }
        }            
        
        # determine the type                 
        if (!$attr->{attribute_type}){
            my $numeric = 1;

            for my $record (@{ $buffer->{records} }){
                if ($record->{$attr->{attribute_name}} and !looks_like_number($record->{$attr->{attribute_name}})){
                    $numeric = 0;
                    last;
                }
            }
            if ($numeric){
                $attr->{attribute_type} = 'NUMERIC';
            }
        }
        if (!$attr->{attribute_type} or $attr->{attribute_type} =~ m/^{.*}$/) {
            $attr->{attribute_type} = '{' . $self->_compose_line(sort keys %values) . '}';
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
