const { PickupRequest, RecyclableType, User, PickupAssignment, sequelize } = require('../models');
const { Op } = require('sequelize');

const pickupController = {
  createPickupRequest: async (req, res) => {
    try {
      const { recyclableTypeId, quantity, pickupDate, frequency, location } = req.body;
      if (!recyclableTypeId || !quantity || !pickupDate) {
        return res.status(400).json({ success: false, message: 'Fill all fields' });
      }

      if (quantity <= 0) {
        return res.status(400).json({ success: false, message: 'Quantity must be more than 0' });
      }

      const parsedDate = new Date(pickupDate);
      if (parsedDate < new Date()) {
        return res.status(400).json({ success: false, message: 'Pick a future date' });
      }

      const type = await RecyclableType.findByPk(recyclableTypeId);
      if (!type) {
        return res.status(404).json({ success: false, message: 'Type not found' });
      }

      const pickupRequest = await PickupRequest.create({
        userId: req.user.id,
        recyclableTypeId,
        quantity,
        pickupDate: parsedDate,
        frequency: frequency || 'One-Time',
        location: location || null,
        status: 'pending',
      });

      console.log(`New pickup request created: ID=${pickupRequest.id}, UserID=${req.user.id}`);

      res.status(201).json({
        success: true,
        message: 'Pickup scheduled',
        pickupRequest: {
          id: pickupRequest.id,
          userId: pickupRequest.userId,
          recyclableTypeId: pickupRequest.recyclableTypeId,
          quantity: pickupRequest.quantity,
          pickupDate: pickupRequest.pickupDate,
          frequency: pickupRequest.frequency,
          location: pickupRequest.location,
          status: pickupRequest.status,
          createdAt: pickupRequest.createdAt,
          updatedAt: pickupRequest.updatedAt,
        },
      });
    } catch (error) {
      console.error('Create pickup request error:', error.message, error.stack);
      res.status(500).json({ success: false, message: 'Error scheduling pickup', error: error.message });
    }
  },

  getPickupRequests: async (req, res) => {
    try {
      let pickupRequests;
      if (req.user.role === 'agent') {
        pickupRequests = await PickupRequest.findAll({
          where: {
            [Op.or]: [
              { status: 'pending' },
              {
                status: { [Op.in]: ['accepted', 'completed', 'cancelled'] }, // Include cancelled requests
                '$assignments.agentId$': req.user.id,
              },
            ],
          },
          include: [
            {
              model: PickupAssignment,
              as: 'assignments',
              include: [{ model: User, as: 'agent', attributes: ['id', 'username', 'email', 'phone', 'profileImage'] }],
              required: false,
            },
            { model: User, as: 'user', attributes: ['id', 'username', 'email', 'phone', 'profileImage'] },
            { model: RecyclableType, as: 'recyclableType', attributes: ['id', 'name'] },
          ],
        });

        pickupRequests = pickupRequests.map(request => {
          const plainRequest = request.get({ plain: true });
          if (plainRequest.assignments) {
            plainRequest.agent = plainRequest.assignments.agent;
          }
          delete plainRequest.assignments;
          return plainRequest;
        });
      } else {
        pickupRequests = await PickupRequest.findAll({
          where: { userId: req.user.id },
          include: [
            { model: RecyclableType, as: 'recyclableType', attributes: ['id', 'name'] },
            {
              model: PickupAssignment,
              as: 'assignments',
              include: [{ model: User, as: 'agent', attributes: ['id', 'username', 'email', 'phone', 'profileImage'] }],
              required: false,
            },
            { model: User, as: 'user', attributes: ['id', 'username', 'email', 'phone', 'profileImage'] },
          ],
        });

        pickupRequests = pickupRequests.map(request => {
          const plainRequest = request.get({ plain: true });
          if (plainRequest.assignments) {
            plainRequest.agent = plainRequest.assignments.agent;
          }
          delete plainRequest.assignments;
          return plainRequest;
        });
      }

      res.json({ success: true, message: 'Pickup requests found', pickupRequests });
    } catch (error) {
      console.error('Get pickup requests error:', error.message, error.stack);
      res.status(500).json({ success: false, message: 'Error getting requests', error: error.message });
    }
  },

  trackPickupRequest: async (req, res) => {
    try {
      const requestId = req.params.id;
      const pickupRequest = await PickupRequest.findByPk(requestId, {
        include: [
          { model: User, as: 'user', attributes: ['id', 'username', 'email', 'phone', 'profileImage'] },
          { model: RecyclableType, as: 'recyclableType', attributes: ['id', 'name'] },
          {
            model: PickupAssignment,
            as: 'assignments',
            include: [{ model: User, as: 'agent', attributes: ['id', 'username', 'email', 'phone', 'profileImage'] }],
            required: false,
          },
        ],
      });

      if (!pickupRequest) {
        return res.status(404).json({ success: false, message: 'Request not found' });
      }

      if (req.user.role !== 'agent' && pickupRequest.userId !== req.user.id) {
        return res.status(403).json({ success: false, message: 'Not authorized' });
      }

      const plainRequest = pickupRequest.get({ plain: true });
      if (plainRequest.assignments) {
        plainRequest.agent = plainRequest.assignments.agent;
      }
      delete plainRequest.assignments;

      res.json({ success: true, message: 'Request found', pickupRequest: plainRequest });
    } catch (error) {
      console.error('Track pickup request error:', error.message, error.stack);
      res.status(500).json({ success: false, message: 'Error tracking request', error: error.message });
    }
  },

  cancelPickupRequest: async (req, res) => {
    try {
      const requestId = req.params.id;
      console.log(`Attempting to cancel request: requestId=${requestId}, userId=${req.user.id}, role=${req.user.role}`);

      const pickupRequest = await PickupRequest.findByPk(requestId);
      if (!pickupRequest) {
        console.log(`Request not found: requestId=${requestId}`);
        return res.status(404).json({ success: false, message: 'Request not found' });
      }

      if (req.user.role === 'agent') {
        const assignment = await PickupAssignment.findOne({
          where: {
            pickupRequestId: requestId,
            agentId: req.user.id,
          },
        });

        if (!assignment) {
          console.log(`Agent not authorized to cancel request: requestId=${requestId}, agentId=${req.user.id}`);
          return res.status(403).json({ success: false, message: 'Not authorized to cancel this request' });
        }

        if (pickupRequest.status !== 'accepted') {
          console.log(`Cannot cancel request: requestId=${requestId}, status=${pickupRequest.status}`);
          return res.status(400).json({ success: false, message: 'Only accepted requests can be cancelled by agents' });
        }
      } else {
        if (pickupRequest.userId !== req.user.id) {
          console.log(`User not authorized to cancel request: requestId=${requestId}, userId=${req.user.id}`);
          return res.status(403).json({ success: false, message: 'Not authorized' });
        }

        // Allow users to cancel both pending and accepted requests
        if (pickupRequest.status !== 'pending' && pickupRequest.status !== 'accepted') {
          console.log(`Cannot cancel request: requestId=${requestId}, status=${pickupRequest.status}`);
          return res.status(400).json({ success: false, message: 'Only pending or accepted requests can be cancelled by users' });
        }
      }

      pickupRequest.status = 'cancelled';
      await pickupRequest.save();

      console.log(`Request cancelled successfully: requestId=${requestId}, userRole=${req.user.role}`);
      res.json({ success: true, message: 'Request cancelled' });
    } catch (error) {
      console.error('Cancel pickup request error:', error.message, error.stack);
      res.status(500).json({ success: false, message: 'Error cancelling request', error: error.message });
    }
  },

  pickupAssign: async (req, res) => {
    try {
      const requestId = req.params.id;
      let agentId;

      if (req.user.role === 'agent') {
        agentId = req.user.id;
        console.log(`Agent ${agentId} attempting to assign request ${requestId}`);
      } else {
        const { agentId: providedAgentId } = req.body;
        if (!providedAgentId) {
          console.log('Agent ID required but not provided');
          return res.status(400).json({ success: false, message: 'Agent ID required' });
        }
        agentId = providedAgentId;
      }

      const pickupRequest = await PickupRequest.findByPk(requestId);
      if (!pickupRequest) {
        console.log(`Request not found: requestId=${requestId}`);
        return res.status(404).json({ success: false, message: 'Request not found' });
      }

      const agent = await User.findByPk(agentId);
      if (!agent) {
        console.error(`Agent not found: agentId=${agentId}`);
        return res.status(404).json({ success: false, message: 'Agent not found' });
      }
      if (agent.role !== 'agent') {
        console.error(`User is not an agent: agentId=${agentId}, role=${agent.role}`);
        return res.status(400).json({ success: false, message: 'User is not an agent' });
      }

      if (pickupRequest.status !== 'pending') {
        console.log(`Cannot assign request: requestId=${requestId}, status=${pickupRequest.status}`);
        return res.status(400).json({ success: false, message: 'Cannot assign request' });
      }

      const existingAssignment = await PickupAssignment.findOne({
        where: { pickupRequestId: requestId },
      });

      if (existingAssignment) {
        console.log(`Request already assigned: requestId=${requestId}, existingAgentId=${existingAssignment.agentId}`);
        return res.status(400).json({ success: false, message: 'Request already assigned' });
      }

      const assignment = await PickupAssignment.create({
        pickupRequestId: requestId,
        agentId: agentId,
      });

      pickupRequest.status = 'accepted';
      await pickupRequest.save();

      const updatedRequest = await PickupRequest.findByPk(requestId, {
        include: [
          { model: User, as: 'user', attributes: ['id', 'username', 'email', 'phone', 'profileImage'] },
          { model: RecyclableType, as: 'recyclableType', attributes: ['id', 'name'] },
          {
            model: PickupAssignment,
            as: 'assignments',
            include: [{ model: User, as: 'agent', attributes: ['id', 'username', 'email', 'phone', 'profileImage'] }],
          },
        ],
      });

      const plainRequest = updatedRequest.get({ plain: true });
      if (plainRequest.assignments) {
        plainRequest.agent = plainRequest.assignments.agent;
      }
      delete plainRequest.assignments;

      console.log(`Request assigned successfully: requestId=${requestId}, agentId=${agentId}`);
      res.json({ success: true, message: 'Request assigned', pickupRequest: plainRequest });
    } catch (error) {
      console.error('Assign pickup request error:', error.message, error.stack);
      res.status(500).json({ success: false, message: 'Error assigning request', error: error.message });
    }
  },

  completePickupRequest: async (req, res) => {
    try {
      const requestId = req.params.id;
      const pickupRequest = await PickupRequest.findByPk(requestId);
      if (!pickupRequest) {
        return res.status(404).json({ success: false, message: 'Pickup request not found' });
      }

      const assignment = await PickupAssignment.findOne({
        where: {
          pickupRequestId: requestId,
          agentId: req.user.id,
        },
      });

      if (!assignment) {
        return res.status(403).json({ success: false, message: 'Not authorized to complete this request' });
      }

      if (pickupRequest.status !== 'accepted') {
        return res.status(400).json({ success: false, message: 'Only accepted requests can be marked as completed' });
      }

      pickupRequest.status = 'completed';
      await pickupRequest.save();

      const updatedRequest = await PickupRequest.findByPk(requestId, {
        include: [
          { model: User, as: 'user', attributes: ['id', 'username', 'email', 'phone', 'profileImage'] },
          { model: RecyclableType, as: 'recyclableType', attributes: ['id', 'name'] },
          {
            model: PickupAssignment,
            as: 'assignments',
            include: [{ model: User, as: 'agent', attributes: ['id', 'username', 'email', 'phone', 'profileImage'] }],
          },
        ],
      });

      const plainRequest = updatedRequest.get({ plain: true });
      if (plainRequest.assignments) {
        plainRequest.agent = plainRequest.assignments.agent;
      }
      delete plainRequest.assignments;

      res.json({ success: true, message: 'Request marked as completed', pickupRequest: plainRequest });
    } catch (error) {
      console.error('Complete pickup request error:', error.message, error.stack);
      res.status(500).json({ success: false, message: 'Error completing request', error: error.message });
    }
  },

  getPickupRequestById: async (requestId) => {
    try {
      const pickupRequest = await PickupRequest.findByPk(requestId);
      if (!pickupRequest) {
        return null;
      }
      return pickupRequest;
    } catch (error) {
      console.error('Get pickup request by ID error:', error.message, error.stack);
      throw new Error('Error fetching pickup request');
    }
  },

  deletePickupRequest: async (requestId) => {
    try {
      const pickupRequest = await PickupRequest.findByPk(requestId);
      if (!pickupRequest) {
        throw new Error('Pickup request not found');
      }
      await pickupRequest.destroy();
    } catch (error) {
      console.error('Delete pickup request error:', error.message, error.stack);
      throw new Error('Error deleting pickup request');
    }
  },
};

module.exports = pickupController;