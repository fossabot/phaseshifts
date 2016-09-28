#!/usr/bin/env python
# encoding: utf-8
##############################################################################
# Author: Liam Deacon                                                        #
#                                                                            #
# Contact: liam.m.deacon@gmail.com                                           #
#                                                                            #
# Copyright: Copyright (C) 2014-2016 Liam Deacon                             #
#                                                                            #
# License: MIT License                                                       #
#                                                                            #
# Permission is hereby granted, free of charge, to any person obtaining a    #
# copy of this software and associated documentation files (the "Software"), #
# to deal in the Software without restriction, including without limitation  #
# the rights to use, copy, modify, merge, publish, distribute, sublicense,   #
# and/or sell copies of the Software, and to permit persons to whom the      #
# Software is furnished to do so, subject to the following conditions:       #
#                                                                            #
# The above copyright notice and this permission notice shall be included in #
# all copies or substantial portions of the Software.                        #
#                                                                            #
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR #
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,   #
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL    #
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER #
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING    #
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER        #
# DEALINGS IN THE SOFTWARE.                                                  #
#                                                                            #
##############################################################################
"""
Provides CLEED validator and Converter classes.

The :py:class`CLEED_validator()` class provides a method for checking
the input files for errors, whereas the :py:meth:`Converter.import_CLEED()`
method allows importing CLEED input files as a :py:class:`MTZModel` instance.

"""

from glob import glob

import math
import os
import sys

from .elements import ELEMENTS
from .utils import expand_filepath

try:
    from io import IOBase
except ImportError:
    from io import iobase as IOBase


class CLEED_validator(object):
    """
    Class for validation of CLEED input files
    """

    def __init__(self):
        """
        Constructor
        """
        pass

    @staticmethod
    def is_CLEED_file(filename):
        """
        Determines if `filename` is a CLEED input file

        Returns
        -------
        True
            if a valid filename ending in any of .bul, .inp, .bsr, .bmin
        False
            otherwise
        """

        # expand filename string and match to first file found
        try:
            filename = glob(expand_filepath(filename))[0]
        except IndexError:  # no file
            raise IOError("filename '%s' not found" % filename)

        # check filename exists
        if not os.path.isfile(filename):
            return False

        # check extension is valid
        ext = os.path.splitext(filename)[1]
        if ext not in ['.bmin', '.bul', '.inp', '.pmin']:
            if ext != '.i':
                sys.stderr.write('Warning: %s is not a valid CLEED extension\n'
                                 % filename)
                sys.stderr.flush()
            return False
        else:
            return True

    @staticmethod
    def validate(filename, aoi=False):
        """
        Checks CLEED input file for errors

        Parameters
        ----------
        filename : str
            Path to input file. Should be \*.bul , \*.ctr, \*.inp or \*.bmin
        aoi : bool
            Check for angle of incidence parameters

        """
        filename = glob(expand_filepath(filename))[0]

        basename, ext = os.path.splitext(filename)
        if isinstance(ext, int):
            #aoi = True
            basename, ext = os.path.splitext(basename)

        if ext in ['.bul', '.bmin', '.bsr']:  # bulk input file
            filetype = 'bulk'
        elif ext in ['.inp', '.pmin', '.par']:  # surface input file
            filetype = 'surface'
        elif ext == '.ctr':  # control file
            filetype = 'control'
        elif ext == '.mkiv':  # mkiv file
            filetype = 'make_iv'
        else:  # try to determine filetype from file data
            with open(filename, 'r') as f:
                # get input lines, stripping left whitespace and comments
                lines = "".join([line.lstrip() for line in f
                                 if not line.lstrip().startswith('#')])
                # check for control parameters
                if ('ef=' in lines and 'ti=' in lines and
                        'id=' in lines and 'wt=' in lines):
                    # probably control file
                    filetype = 'control'
                elif ('pb:' in lines and ('ei:' in lines or 'ef:' in lines or
                                          'es:' in lines or 'ep:' in lines or
                                          'vi:' in lines or 'vr:' in lines or
                                          'lm:' in lines or 'm1:' in lines or
                                          'm2:' in lines
                                          )):  # probably bulk file
                    filetype = 'bulk'
                elif ('po:' in lines and ('a1:' in lines or 'a2:' in lines or
                                          'm1:' in lines or
                                          'm2:' in lines)):  # surface file?
                    filetype = 'surface'
                elif ('po:' in lines and not ('a1:' in lines or
                                              'a2:' in lines or
                                              'm1:' in lines or
                                              'm2:' in lines)):
                    filetype = 'parameter'
                else:
                    raise IOError("unknown CLEED format for file '%s'"
                                  % filename)

        with open(filename, 'r') as f:
            # get input lines, stripping left whitespace and comments
            lines = [line for line in f]

        with open(filename, 'w') as f:
            for (i, line) in enumerate(lines):
                line = line.lstrip().rstrip()
                if not line.startswith('#') or line.startswith(''):
                    # process line based on file type
                    if line.startswith('po:'):
                        if filetype not in ['surface', 'parameter']:
                            # comment out line
                            sys.stderr.write('warning: commented out line '
                                             '%i\n' % i)
                            sys.stderr.flush()
                            line = '#' + line

                    else:  # line unknown - comment out
                        sys.stderr.write('warning: commented out line '
                                         '%i\n' % i)
                        sys.stderr.flush()
                        line = '#' + line
                    if filetype == 'bulk' or filetype == 'surface':
                        pass
                f.write(line + '\r\n')  # playing it safe with line endings
                sys.stderr.flush()
        # unit cell
        try:
            _basis = [line for line in lines if line.startswith('a') and
                      int(line[1]) <= 3 and int(line[1]) > 0]

        except ValueError:
            raise ValueError("'%s' is not a valid basis vector"
                             % line[:2])

        # try to get minimum radii for mufftin input
        try:
            minimum_radii = ["".join(line.split(':')[1].split()[:4])
                             for line in lines if line.startswith('rm:')]
        except ValueError:
            raise ValueError("'%s' is not a valid minimum radius input"
                             % line[:2])
        radii_dict = {}
        for radius in minimum_radii:
            tag, value = zip((str, float), radius.split()[:2])
            radii_dict[tag] = value

        try:
            _overlayer_atoms = ["".join(line.split(':')[1].split()[:4])
                                for line in lines
                                if line.startswith('po:')]
        except ValueError:
            raise ValueError("'%s' is not a valid overlayer atom input"
                             % line[:2])

        try:
            _bulk_atoms = ["".join(line.split(':')[1].split()[:4])
                           for line in lines if line.startswith('pb:')]
        except ValueError:
            raise ValueError("'%s' is not a valid overlayer atom input"
                             % line[:2])


class Converter(object):
    """
    Convert different input into phaseshift compatible input
    """

    def __init__(self):
        """
        Constructor
        """
        pass

    @staticmethod
    def import_CLEED(filename, **kwargs):
        """
        Imports CLEED input file and converts model to muffin-tin input.

        It assumes the following:
          * the basis vectors :math:`a_1`, :math:`a_2`, & :math:`a_3` are
            :math:`x`,:math:`y`,:math:`z` cartezian coordinates
          * if no :math:`a_3` is found, the maximum :math:`z` distance between
          atoms multiplied by four is given.
          * the unitcell is converted from cartezian to fractional coordinates
          * atom sites are converted from Angstrom to Bohr units
          * additional info from the phase shift filename is provided by
          splitting the '_' chars:
            1. First string segment is element or symbol, e.g. Ni
            2. Second string segment is the oxidation (valence), e.g. +2
          * lines with :code:`rm:` provide the radii dictionary of the
            individual phase shifts, whereas lines starting with
            :code:`lmax:` provide the lmax dictionary for individual phase
            shifts. Additionally, the valency can be given in lines
            starting with :code:`ox:`. Both bulk and surface input files
            will be searched for these.
          * if no :code:`rm:` found for that species, the atomic radius is used
            for zero valence, otherwise the covalent radius is used.
          * if no lmax values are found for the specific phase shift, then the
            global value will be used instead.
          * if no valence values are found for the specific phase shift, then
            the guessed oxidation value from the phase shift filename is used
            instead. However, if the oxidation state cannot be parsed using
            the filename then a default oxidation state of zero is used.

        Additional information can, however, be provided using 'phs:' at the
        start of a line within the input file and may have the following
        formats:
          1. "**phs:** c *<float>* nh *<int>* nform *<int>* exchange *<float>*"
          2. "**phs:** *<phase_shift>* valence *<float>* radius *<float>*"

        The identifiers ``exchange``, ``nform``, ``valence`` and ``radius`` may
        be abbreviated to ``exc``, ``nf``, ``val`` and ``rad``, respectively.

        Information given in this manner overrides any other input.


        Parameters
        ----------
        filename : str
            Path to input file.

        Returns
        -------
        muffpot_model : phaseshifts.model.MTZModel
            Muffin-tin potential model for phase shift calculations.

        Raises
        ------
        IOError
            If filename invalid.
        ValueError
            If input contains bad formatting.
        """

        try:
            verbose = kwargs['verbose']
        except KeyError:
            verbose = False

        if not isinstance(filename, str):
            # careful: passing file object not string
            raise IOError("'%s' is not a string" % filename)

        filename = glob(os.path.expanduser(os.path.expandvars(filename)))[0]

        if os.path.isdir(filename):
            # check directory for unique .bul or .bmin files
            raise IOError("'%s' is a directory, not a file" % filename)

        elif os.path.isfile(filename):
            # determine type of file
            name, ext = os.path.splitext(filename)

            if ext in ['.bul', '.bmin']:  # bulk input file
                if os.path.isfile(name + '.inp'):
                    surface_input = name + '.inp'
                elif os.path.isfile(name + '.pmin'):
                    surface_input = name + '.pmin'
                elif os.path.isfile(name + '.par'):
                    surface_input = name + '.par'
                else:
                    surface_input = None
                    sys.stderr.write("cannot find a suitable CLEED surface "
                                     "input file matching '%s'" % filename)
                    sys.stderr.flush()
                bulk_input = filename
            elif ext in ['.inp', '.pmin', '.par']:  # surface input file
                surface_input = filename
                if os.path.isfile(name + '.bul'):
                    bulk_input = name + '.bul'
                elif os.path.isfile(name + '.bmin'):
                    bulk_input = name + '.bmin'
                else:
                    bulk_input = None
                    sys.stderr.write("cannot find a suitable CLEED bulk "
                                     "input file matching '%s'" % filename)
                    sys.stderr.flush()

            try:
                with open(bulk_input, 'r') as f:
                    bulk_lines = [line for line in f
                                  if not line.lstrip().startswith('#')]

            except IOError:
                bulk_lines = []

            try:
                with open(surface_input, 'r') as f:
                    surface_lines = [line for line in f
                                     if not line.lstrip().startswith('#')]

            except IOError:
                surface_lines = []

        else:
            raise IOError("cannot open '%s'" % filename)

        lines = surface_lines + bulk_lines

        # initialise model
        from phaseshifts import model  # delay import until actual needed
        atoms = []
        radii_dict = {}
        lmax_dict = {}
        oxidation_dict = {}
        unitcell = model.Unitcell(1, 2, [[1, 0, 0], [0, 1, 0], [0, 0, 1]])
        z_dist = 4.0  # calculate 'c' for slab from atom coordinates
        z_min = sys.float_info.max
        z_max = sys.float_info.min
        title = "/".join([line.split(':')[1].lstrip()
                          for line in lines
                          if line.startswith('c:')])

        # Hartree-Fock exchange term alpha
        try:
            alpha = float([line.split(':')[1] for line in lines
                           if line.startswith('alpha:') or
                           line.startswith('exchange:') or
                           line.startswith('exc:')][0])
        except (ValueError, IndexError):
            alpha = None

        # unit cell
        basis = [line for line in lines if line.startswith('a') and
                 int(line[1]) <= 3 and int(line[1]) > 0]

        a1 = a2 = a3 = [0.0, 0.0, 0.0]  # intialise basis vectors
        for vector_line in basis:
            line = " ".join(vector_line.replace(':', '').split()[:4])

            try:
                (_vector_str, x, y, z) = [t(s)
                                          for (t, s) in zip([str] +
                                                            [float] * 3,
                                                            line.split())]
            except ValueError:
                raise ValueError("'%s' is not a valid basis vector"
                                 % vector_line.replace('\n', ''))

            _vector_str = list(map(float, (x, y, z)))

        zmin = sys.float_info.max
        a = zmax = sys.float_info.min
        for vector in [a1, a2, a3]:

            # compare magnitude of xy components
            len_a = math.sqrt(math.pow(vector[0], 2) + math.pow(vector[1], 2))
            if len_a > a:
                a = len_a

            # find min and max z
            if vector[2] < zmin:
                zmin = vector[2]

            if vector[2] > zmax:
                zmax = vector[2]

        # try to get minimum radii for mufftin input
        try:
            minimum_radii = [" ".join(line.split(':')[1].split()[:4])
                             for line in lines
                             if line.startswith('rm:')]

            for radius in minimum_radii:
                tag, value = zip((str, float), radius.split()[:2])
                radii_dict[tag] = value

        except ValueError:
            raise ValueError("'%s' is not a valid minimum radius input"
                             % line[:2])

        # try to get lmax values for each phaseshift type
        try:
            lmax_values = [" ".join(line.split(':')[1].split()[:4])
                           for line in lines
                           if line.startswith('lmax:')]

            for lmax_str in lmax_values:
                tag, value = [t(s) for t, s in zip((str, int),
                                                   lmax_str.split()[:2])]
                lmax_dict[tag] = value

        except ValueError:
            raise ValueError("'%s' is not a valid lmax input"
                             % line[:2])

        # try to get oxidation values for each phaseshift type
        try:
            oxidation_values = [" ".join(line.split(':')[1].split()[:4])
                                for line in lines
                                if line.startswith('val:')]

            for oxi_str in oxidation_values:
                tag, value = [t(s) for t, s in zip((str, float),
                                                   oxi_str.split()[:2])]
                oxidation_dict[tag] = value

        except ValueError:
            raise ValueError("'%s' is not a valid valency (oxidation state)"
                             % line[:2])

        # try to get the overlayer atoms
        overlayer_atoms = [" ".join(line.split(':')[1].split()[:4])
                           for line in lines if line.startswith('po:')]

        # extract details for each overlayer atom
        for overlayer_atom in overlayer_atoms:
            try:
                id_str, x, y, z = [t(s) for t, s in zip((str, float,
                                                         float, float),
                                                        overlayer_atom.split())]

            except ValueError:
                raise ValueError("'%s' line input is invalid")

            # extract further information from id string
            id_str = os.path.basename(expand_filepath(id_str))
            element = id_str.split('_')[0]  # assume element name / symbol
            element = "".join([ch for ch in element if ch.isalpha()])

            if element not in ELEMENTS:
                raise NameError("Unknown element '%s' from phase shift name"
                                "'%s'" % (element, id_str))

            # try to determine oxidation state from string
            oxidation = None
            if id_str in oxidation_dict:
                oxidation = oxidation_dict[id_str]
            else:
                try:
                    oxidation = str(id_str.split('_')[1])  # assume valence 2nd
                    if oxidation.startswith('-') or oxidation.startswith('+'):
                        oxidation = float(oxidation)
                    elif oxidation.endswith('-') or oxidation.endswith('+'):
                        if oxidation.endswith('-'):
                            oxidation = float(oxidation.rstrip('-'))
                        else:
                            oxidation = float(oxidation.rstrip('+'))
                    else:
                        oxidation = 0.0  # oxidation not specified
                except (IndexError, ValueError):  # invalid oxidation substring
                    pass
                finally:
                    if oxidation is None:
                        oxidation = 0.0  # default oxidation if not specified

            rm = None
            try:
                rm = radii_dict[id_str]
            except KeyError:
                pass

            lmax = None
            try:
                lmax = lmax_dict[id_str]
            except KeyError:
                pass

            if lmax is None:
                try:  # to get lmax from id string
                    substrings = [s for s in id_str.lower().split('_')
                                  if s.startswith('lmax')]
                    if substrings:
                        lmax = int("".join([s for s in substrings[0]
                                            if s.isdigit()]))
                except ValueError:
                    pass

            if rm and lmax:
                atom = model.Atom(element, [x, y, z], tag=id_str,
                                  valence=oxidation, radius=rm, lmax=lmax)
            elif rm and not lmax:
                atom = model.Atom(element, [x, y, z], tag=id_str,
                                  valence=oxidation, radius=rm)
            elif not rm and lmax:
                atom = model.Atom(element, [x, y, z], tag=id_str,
                                  valence=oxidation, lmax=lmax)
            else:
                atom = model.Atom(element, [x, y, z], tag=id_str,
                                  valence=oxidation)

            # update z limits
            if z < z_min:
                z_min = z
            if z > z_max:
                z_max = z

            # add atom to list
            atoms.append(atom)

        # try to get the bulk atoms
        bulk_atoms = [" ".join(line.split(':')[1].split()[:4])
                      for line in lines if line.startswith('pb:')]
        if verbose:
            print("CLEED model")
            print("\tbulk atoms: %s" % [s for s in bulk_atoms])

        # extract details for each bulk atom
        for bulk_atom in bulk_atoms:
            # split line data
            try:
                (id_str, x, y, z) = [t(s) for t, s in zip(
                                     (str, float, float, float),
                                     bulk_atom.split())]
                # extract further information from id string
                id_str = os.path.basename(expand_filepath(id_str))
                element = id_str.split('_')[0]  # assume element name / symbol
                element = "".join([ch for ch in element if ch.isalpha()])

                if element not in ELEMENTS:
                    raise NameError("Unknown element '%s' from phase "
                                    "shift name '%s'" % (element, id_str))

            except ValueError:
                print("'%s' line input is invalid")
                raise ValueError("'%s' line input is invalid")

            # try to determine oxidation state from string
            oxidation = None
            if id_str in oxidation_dict:
                oxidation = oxidation_dict[id_str]
            else:
                try:
                    oxidation = str(id_str.split('_')[1])  # assume valence 2nd
                    if oxidation.startswith('-') or oxidation.startswith('+'):
                        oxidation = float(oxidation)
                    elif oxidation.endswith('-') or oxidation.endswith('+'):
                        if oxidation.endswith('-'):
                            oxidation = float(oxidation.rstrip('-'))
                        else:
                            oxidation = float(oxidation.rstrip('+'))
                    else:
                        oxidation = 0.0  # oxidation not specified
                except (IndexError, ValueError):  # invalid oxidation substring
                    pass
                finally:
                    if oxidation is None:
                        oxidation = 0.0  # default oxidation if not specified

            rm = None
            if id_str in radii_dict:
                rm = radii_dict[id_str]

            lmax = None
            if id_str in lmax_dict:
                lmax = lmax_dict[id_str]

            if rm and lmax:
                atom = model.Atom(element, [x, y, z], tag=id_str,
                                  valence=oxidation, radius=rm, lmax=lmax)
            elif rm and not lmax:
                atom = model.Atom(element, [x, y, z], tag=id_str,
                                  valence=oxidation, radius=rm)
            elif not rm and lmax:
                atom = model.Atom(element, [x, y, z], tag=id_str,
                                  valence=oxidation, lmax=lmax)
            else:
                atom = model.Atom(element, [x, y, z], tag=id_str,
                                  valence=oxidation)

            # update z limits
            if z < z_min:
                z_min = z
            if z > z_max:
                z_max = z

            # add atom to list
            atoms.append(atom)

        # change basis to fractional coordinates (SPA units)
        # i.e. in terms of magnitude 'a'
        for vector in [a1, a2, a3]:
            vector = [x / a for x in vector]

        if a3 == [0.0, 0.0, 0.0]:  # no a3 in input file => slab
            z_dist = (z_max - z_min) / float(a) / 0.529
            c = z_dist * 5  # slab calculation
            a3[2] = c
        else:
            c = a3[2] / float(a) / 0.529

        # create unitcell
        unitcell = model.Unitcell(a, c, [a1, a2, a3])

        muffpot_model = model.MTZModel(unitcell, atoms)
        muffpot_model.name = title

        if alpha:
            muffpot_model.exchange = alpha

        # read additional phaseshift statement lines 'phs:'
        phs_lines = [line.lower().lstrip("phs:").rstrip("#")
                     for line in lines if line.lower().startswith("phs:")]

        for line in phs_lines:
            strings = line.split()
            phase_shift = strings[0]
            phs_atoms = [atom.tag for atom in muffpot_model.atoms
                         if atom.tag == phase_shift]
            if phase_shift not in phs_atoms:
                for i in range(len(strings)):
                    try:
                        if strings[i] == 'c':
                            c = strings[i] / float(a) / 0.529
                            muffpot_model.unitcell.c = c

                        elif strings[i] == 'nh':
                            muffpot_model.nh = strings[i + 1]

                        elif (strings[i] == 'exc' or
                              strings[i] == 'exchange'):
                            muffpot_model.exchange = strings[i + 1]

                        elif (strings[i] == 'nf' or
                              strings[i] == 'nform'):
                            muffpot_model.nform = strings[i + 1]

                    except IndexError:
                        break
            else:

                # apply commands to atom
                for i in range(1, len(strings)):
                    try:
                        if (strings[i] == 'val' or
                                strings[i] == 'valence'):
                            for atom in phs_atoms:
                                atom.valence = float(strings[i + 1])

                        elif (strings[i] == 'rad' or
                              strings[i] == 'radius'):
                            for atom in phs_atoms:
                                atom.radius = float(strings[i + 1])

                    except IndexError:
                        break

        return muffpot_model  # converted muffin-tin potential model


class CSearch(object):
    """class for csearch related data exchange"""

    def __init__(self, model_name, leed_command=None):
        self.set_Model(model_name)
        self._getResults()

    def setModel(self, name):
        """sets the model name"""
        self.model = str(name)

    def getIterationInfo(self, iteration):
        """ Returns information associated with given iteration """
        try:
            with open(self.model + '.log', 'r') as f:
                return [line for line in f if line.startswith('#') and
                        'par' in line][int(iteration)]
        except (IndexError, ValueError, IOError):
            return None

    def getRFactor(self, iteration):
        """ Returns the R-Factor for the given iteration """
        pass

    def getTimeStamp(self, iteration):
        """ Returns the timestamp for the given iteration """
        pass

    def _getResults(self):
        pass
